import math
from contextlib import asynccontextmanager
from typing import Dict, List, Optional

from fastapi import Depends, FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import and_, func, or_
from sqlalchemy.orm import Session

from . import config
from .ai import ask_groq
from .database import Base, SessionLocal, engine, get_db
from .models import AssistanceRequest, Message, Part, Review, User, Vehicle, now
from .schemas import (AiIn, LoginIn, MessageIn, PartIn, ProfileIn, RegisterIn, RequestIn,
                      ReviewIn, StatusIn, StockIn, VehicleIn)
from .security import create_token, current_user, decode_token, hash_password, verify_password
from .seed import seed


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        seed(db)
    finally:
        db.close()
    yield


app = FastAPI(title="AutoAssist API", version="1.0.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


# ----------------------------------------------------------------- helpers
def haversine(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = p2 - p1, math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def iso(dt) -> Optional[str]:
    return dt.isoformat() + "Z" if dt else None


def user_out(u: User) -> dict:
    """Full profile - only ever sent to the account owner."""
    return {
        "id": u.id, "name": u.name, "email": u.email, "phone": u.phone or "", "role": u.role,
        "business_name": u.business_name or "", "address": u.address or "",
        "lat": u.lat, "lng": u.lng, "specialization": u.specialization or "",
        "services": u.services or "", "bio": u.bio or "", "available": bool(u.available),
    }


def public_user(u: User) -> dict:
    d = user_out(u)
    d.pop("email")
    return d


def rating_stats(db: Session) -> Dict[int, tuple]:
    rows = (db.query(Review.mechanic_id, func.avg(Review.rating), func.count(Review.id))
            .group_by(Review.mechanic_id).all())
    return {r[0]: (round(float(r[1]), 1), int(r[2])) for r in rows}


def mech_out(u: User, stats: Dict[int, tuple], lat: Optional[float], lng: Optional[float]) -> dict:
    d = public_user(u)
    rating, count = stats.get(u.id, (0.0, 0))
    d["rating"] = rating
    d["reviews_count"] = count
    d["distance_km"] = None
    if lat is not None and lng is not None and u.lat is not None and u.lng is not None:
        d["distance_km"] = round(haversine(lat, lng, u.lat, u.lng), 1)
    return d


def request_out(r: AssistanceRequest, viewer: User, db: Session) -> dict:
    driver = db.get(User, r.driver_id)
    mech = db.get(User, r.mechanic_id) if r.mechanic_id else None
    vehicle = db.get(Vehicle, r.vehicle_id) if r.vehicle_id else None
    # Privacy: a mechanic who has not accepted yet only sees an approximate area.
    hidden = viewer.role == "mechanic" and r.mechanic_id != viewer.id
    lat, lng = (round(r.lat, 2), round(r.lng, 2)) if hidden else (r.lat, r.lng)
    dist = None
    if viewer.role == "mechanic" and viewer.lat is not None and viewer.lng is not None:
        dist = round(haversine(viewer.lat, viewer.lng, r.lat, r.lng), 1)
    vehicle_text = None
    if vehicle:
        vehicle_text = f"{vehicle.year} {vehicle.make} {vehicle.model}"
        if vehicle.plate:
            vehicle_text += f" ({vehicle.plate})"
    return {
        "id": r.id, "status": r.status, "problem": r.problem, "description": r.description or "",
        "lat": lat, "lng": lng, "approximate": hidden,
        "created_at": iso(r.created_at), "updated_at": iso(r.updated_at),
        "vehicle": vehicle_text,
        "driver": ({"id": driver.id, "name": driver.name, "phone": None if hidden else driver.phone}
                   if driver else None),
        "mechanic": ({"id": mech.id, "name": mech.name, "business_name": mech.business_name or "",
                      "phone": mech.phone or "", "lat": mech.lat, "lng": mech.lng} if mech else None),
        "distance_km": dist,
    }


def message_out(m: Message) -> dict:
    return {"id": m.id, "request_id": m.request_id, "sender_id": m.sender_id,
            "text": m.text, "created_at": iso(m.created_at)}


def load_request(db: Session, rid: int, user: User) -> AssistanceRequest:
    r = db.get(AssistanceRequest, rid)
    if r is None:
        raise HTTPException(404, "Request not found.")
    if user.id in (r.driver_id, r.mechanic_id):
        return r
    if user.role == "mechanic" and r.mechanic_id is None and r.status == "pending":
        return r
    raise HTTPException(403, "You do not have access to this request.")


def can_chat(r: AssistanceRequest, user: User) -> bool:
    return r.mechanic_id is not None and user.id in (r.driver_id, r.mechanic_id)


def part_out(p: Part, s: User) -> dict:
    return {
        "id": p.id, "name": p.name, "category": p.category, "brand": p.brand or "",
        "price": p.price or 0, "compatible": p.compatible or "", "in_stock": bool(p.in_stock),
        "location": p.location or s.address or "", "supplier_id": s.id,
        "supplier_name": s.business_name or s.name, "supplier_phone": s.phone or "",
    }


# ----------------------------------------------------------------- websocket hub
class Hub:
    def __init__(self):
        self.rooms: Dict[int, List[WebSocket]] = {}

    async def join(self, rid: int, ws: WebSocket):
        await ws.accept()
        self.rooms.setdefault(rid, []).append(ws)

    def leave(self, rid: int, ws: WebSocket):
        room = self.rooms.get(rid, [])
        if ws in room:
            room.remove(ws)

    async def broadcast(self, rid: int, data: dict):
        for ws in list(self.rooms.get(rid, [])):
            try:
                await ws.send_json(data)
            except Exception:
                self.leave(rid, ws)


hub = Hub()


# ----------------------------------------------------------------- general
@app.get("/")
def root():
    return {"app": "AutoAssist API", "docs": "/docs"}


@app.get("/health")
def health():
    return {"status": "ok", "ai_configured": bool(config.GROQ_API_KEY), "model": config.GROQ_MODEL}


# ----------------------------------------------------------------- auth & profile
@app.post("/auth/register")
def register(body: RegisterIn, db: Session = Depends(get_db)):
    email = body.email.strip().lower()
    if "@" not in email or "." not in email.split("@")[-1]:
        raise HTTPException(400, "Enter a valid email address.")
    if body.role not in ("driver", "mechanic", "supplier"):
        raise HTTPException(400, "Choose a valid account type.")
    if db.query(User).filter(User.email == email).first():
        raise HTTPException(400, "An account with this email already exists.")
    user = User(
        name=body.name.strip(), email=email, phone=body.phone.strip(),
        password_hash=hash_password(body.password), role=body.role,
        business_name=body.business_name.strip(),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return {"token": create_token(user.id), "user": user_out(user)}


@app.post("/auth/login")
def login(body: LoginIn, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == body.email.strip().lower()).first()
    if user is None or not verify_password(body.password, user.password_hash):
        raise HTTPException(401, "Incorrect email or password.")
    return {"token": create_token(user.id), "user": user_out(user)}


@app.get("/me")
def me(user: User = Depends(current_user)):
    return user_out(user)


@app.put("/me")
def update_me(body: ProfileIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    data = body.model_dump(exclude_none=True)
    if "name" in data and len(data["name"].strip()) < 2:
        raise HTTPException(400, "Name is too short.")
    for key, value in data.items():
        if key in ("specialization", "services", "bio", "business_name", "address", "phone", "name"):
            value = value.strip()
        setattr(user, key, value)
    db.commit()
    db.refresh(user)
    return user_out(user)


# ----------------------------------------------------------------- vehicles
@app.get("/vehicles")
def list_vehicles(user: User = Depends(current_user), db: Session = Depends(get_db)):
    rows = db.query(Vehicle).filter(Vehicle.owner_id == user.id).order_by(Vehicle.id.desc()).all()
    return [{"id": v.id, "make": v.make, "model": v.model, "year": v.year,
             "plate": v.plate or "", "vtype": v.vtype or "Car"} for v in rows]


@app.post("/vehicles")
def add_vehicle(body: VehicleIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    v = Vehicle(owner_id=user.id, make=body.make.strip(), model=body.model.strip(), year=body.year,
                plate=body.plate.strip().upper(), vtype=body.vtype)
    db.add(v)
    db.commit()
    db.refresh(v)
    return {"id": v.id, "make": v.make, "model": v.model, "year": v.year, "plate": v.plate, "vtype": v.vtype}


@app.delete("/vehicles/{vid}")
def delete_vehicle(vid: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    v = db.get(Vehicle, vid)
    if v is None or v.owner_id != user.id:
        raise HTTPException(404, "Vehicle not found.")
    db.query(AssistanceRequest).filter(AssistanceRequest.vehicle_id == vid).update({"vehicle_id": None})
    db.delete(v)
    db.commit()
    return {"ok": True}


# ----------------------------------------------------------------- mechanics
@app.get("/mechanics")
def list_mechanics(lat: Optional[float] = None, lng: Optional[float] = None, q: str = "",
                   category: str = "", user: User = Depends(current_user),
                   db: Session = Depends(get_db)):
    rows = db.query(User).filter(User.role == "mechanic", User.lat.isnot(None), User.lng.isnot(None)).all()
    stats = rating_stats(db)
    items = []
    needle = q.strip().lower()
    cat = category.strip().lower()
    for u in rows:
        if cat and cat not in (u.specialization or "").lower():
            continue
        if needle:
            hay = " ".join([u.name or "", u.business_name or "", u.address or "",
                            u.specialization or "", u.services or ""]).lower()
            if needle not in hay:
                continue
        items.append(mech_out(u, stats, lat, lng))
    if lat is not None and lng is not None:
        items.sort(key=lambda d: d["distance_km"] if d["distance_km"] is not None else 1e9)
    else:
        items.sort(key=lambda d: -d["rating"])
    return items


@app.get("/mechanics/{mid}")
def mechanic_detail(mid: int, lat: Optional[float] = None, lng: Optional[float] = None,
                    user: User = Depends(current_user), db: Session = Depends(get_db)):
    u = db.get(User, mid)
    if u is None or u.role != "mechanic":
        raise HTTPException(404, "Mechanic not found.")
    d = mech_out(u, rating_stats(db), lat, lng)
    revs = (db.query(Review).filter(Review.mechanic_id == mid)
            .order_by(Review.created_at.desc()).limit(20).all())
    names = {}
    if revs:
        ids = [r.driver_id for r in revs]
        names = {x.id: x.name for x in db.query(User).filter(User.id.in_(ids)).all()}
    d["reviews"] = [{"id": r.id, "rating": r.rating, "comment": r.comment or "",
                     "driver_name": names.get(r.driver_id, "Driver"),
                     "created_at": iso(r.created_at)} for r in revs]
    return d


@app.post("/mechanics/{mid}/reviews")
def add_review(mid: int, body: ReviewIn, user: User = Depends(current_user),
               db: Session = Depends(get_db)):
    if user.role != "driver":
        raise HTTPException(403, "Only drivers can leave reviews.")
    mech = db.get(User, mid)
    if mech is None or mech.role != "mechanic":
        raise HTTPException(404, "Mechanic not found.")
    existing = db.query(Review).filter(Review.mechanic_id == mid, Review.driver_id == user.id).first()
    if existing:
        existing.rating = body.rating
        existing.comment = body.comment.strip()
        existing.created_at = now()
    else:
        db.add(Review(mechanic_id=mid, driver_id=user.id, rating=body.rating, comment=body.comment.strip()))
    db.commit()
    return {"ok": True}


# ----------------------------------------------------------------- assistance requests
@app.post("/requests")
def create_request(body: RequestIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    if user.role != "driver":
        raise HTTPException(403, "Only drivers can request assistance.")
    if body.vehicle_id is not None:
        v = db.get(Vehicle, body.vehicle_id)
        if v is None or v.owner_id != user.id:
            raise HTTPException(400, "Selected vehicle was not found.")
    if body.mechanic_id is not None:
        m = db.get(User, body.mechanic_id)
        if m is None or m.role != "mechanic":
            raise HTTPException(400, "Selected mechanic was not found.")
    r = AssistanceRequest(driver_id=user.id, vehicle_id=body.vehicle_id, mechanic_id=body.mechanic_id,
                          problem=body.problem.strip(), description=body.description.strip(),
                          lat=body.lat, lng=body.lng, status="pending")
    db.add(r)
    db.commit()
    db.refresh(r)
    return request_out(r, user, db)


@app.get("/requests")
def list_requests(user: User = Depends(current_user), db: Session = Depends(get_db)):
    q = db.query(AssistanceRequest)
    if user.role == "driver":
        q = q.filter(AssistanceRequest.driver_id == user.id)
    elif user.role == "mechanic":
        q = q.filter(or_(
            AssistanceRequest.mechanic_id == user.id,
            and_(AssistanceRequest.mechanic_id.is_(None), AssistanceRequest.status == "pending"),
        ))
    else:
        raise HTTPException(403, "Requests are not available for this account type.")
    rows = q.order_by(AssistanceRequest.created_at.desc()).limit(100).all()
    return [request_out(r, user, db) for r in rows]


@app.get("/requests/{rid}")
def get_request(rid: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    return request_out(load_request(db, rid, user), user, db)


@app.patch("/requests/{rid}/status")
def update_status(rid: int, body: StatusIn, user: User = Depends(current_user),
                  db: Session = Depends(get_db)):
    r = load_request(db, rid, user)
    new = body.status
    if user.id == r.driver_id:
        if new != "cancelled":
            raise HTTPException(400, "Drivers can only cancel a request.")
        if r.status in ("completed", "cancelled"):
            raise HTTPException(400, "This request is already closed.")
    elif user.role == "mechanic":
        if new == "accepted":
            if r.status != "pending":
                raise HTTPException(400, "This request is no longer available.")
            if r.mechanic_id not in (None, user.id):
                raise HTTPException(403, "This request was sent to another mechanic.")
            r.mechanic_id = user.id
        elif new in ("en_route", "completed"):
            if r.mechanic_id != user.id:
                raise HTTPException(403, "Accept the request first.")
            allowed = {"en_route": ("accepted",), "completed": ("accepted", "en_route")}
            if r.status not in allowed[new]:
                raise HTTPException(400, "That status change is not allowed right now.")
        else:
            raise HTTPException(400, "Invalid status.")
    else:
        raise HTTPException(403, "Not allowed.")
    r.status = new
    r.updated_at = now()
    db.commit()
    db.refresh(r)
    return request_out(r, user, db)


# ----------------------------------------------------------------- chat
@app.get("/requests/{rid}/messages")
def list_messages(rid: int, after_id: int = 0, user: User = Depends(current_user),
                  db: Session = Depends(get_db)):
    r = db.get(AssistanceRequest, rid)
    if r is None or not can_chat(r, user):
        raise HTTPException(403, "Chat opens once a mechanic is assigned to the request.")
    rows = (db.query(Message).filter(Message.request_id == rid, Message.id > after_id)
            .order_by(Message.id).limit(300).all())
    return [message_out(m) for m in rows]


@app.post("/requests/{rid}/messages")
async def post_message(rid: int, body: MessageIn, user: User = Depends(current_user),
                       db: Session = Depends(get_db)):
    r = db.get(AssistanceRequest, rid)
    if r is None or not can_chat(r, user):
        raise HTTPException(403, "Chat opens once a mechanic is assigned to the request.")
    if r.status == "cancelled":
        raise HTTPException(400, "This request was cancelled.")
    m = Message(request_id=rid, sender_id=user.id, text=body.text.strip())
    db.add(m)
    db.commit()
    db.refresh(m)
    out = message_out(m)
    await hub.broadcast(rid, out)
    return out


@app.websocket("/ws/requests/{rid}")
async def chat_socket(ws: WebSocket, rid: int, token: str = ""):
    uid = decode_token(token)
    db = SessionLocal()
    try:
        user = db.get(User, uid) if uid else None
        r = db.get(AssistanceRequest, rid)
        allowed = bool(user and r and can_chat(r, user))
    finally:
        db.close()
    if not allowed:
        await ws.close(code=4403)
        return
    await hub.join(rid, ws)
    try:
        while True:
            await ws.receive_text()  # messages are sent through the REST endpoint
    except WebSocketDisconnect:
        pass
    except Exception:
        pass
    finally:
        hub.leave(rid, ws)


# ----------------------------------------------------------------- spare parts
@app.get("/parts")
def search_parts(q: str = "", category: str = "", user: User = Depends(current_user),
                 db: Session = Depends(get_db)):
    query = db.query(Part, User).join(User, Part.supplier_id == User.id)
    if category.strip():
        query = query.filter(func.lower(Part.category) == category.strip().lower())
    if q.strip():
        like = f"%{q.strip().lower()}%"
        query = query.filter(or_(func.lower(Part.name).like(like), func.lower(Part.brand).like(like),
                                 func.lower(Part.compatible).like(like), func.lower(Part.category).like(like)))
    rows = query.order_by(Part.in_stock.desc(), Part.name).limit(100).all()
    return [part_out(p, s) for p, s in rows]


@app.get("/parts/mine")
def my_parts(user: User = Depends(current_user), db: Session = Depends(get_db)):
    if user.role != "supplier":
        raise HTTPException(403, "Only parts suppliers have a parts list.")
    rows = db.query(Part).filter(Part.supplier_id == user.id).order_by(Part.id.desc()).all()
    return [part_out(p, user) for p in rows]


@app.post("/parts")
def add_part(body: PartIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    if user.role != "supplier":
        raise HTTPException(403, "Only parts suppliers can list parts.")
    p = Part(supplier_id=user.id, name=body.name.strip(), category=body.category, brand=body.brand.strip(),
             price=body.price, compatible=body.compatible.strip(), in_stock=body.in_stock,
             location=body.location.strip() or user.address or "")
    db.add(p)
    db.commit()
    db.refresh(p)
    return part_out(p, user)


@app.patch("/parts/{pid}/stock")
def set_stock(pid: int, body: StockIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    p = db.get(Part, pid)
    if p is None or p.supplier_id != user.id:
        raise HTTPException(404, "Part not found.")
    p.in_stock = body.in_stock
    db.commit()
    return part_out(p, user)


@app.delete("/parts/{pid}")
def delete_part(pid: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    p = db.get(Part, pid)
    if p is None or p.supplier_id != user.id:
        raise HTTPException(404, "Part not found.")
    db.delete(p)
    db.commit()
    return {"ok": True}


# ----------------------------------------------------------------- AI assistant
@app.post("/ai/chat")
async def ai_chat(body: AiIn, user: User = Depends(current_user)):
    reply = await ask_groq(body.messages, body.vehicle)
    return {"reply": reply}
