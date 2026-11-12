from datetime import datetime, timezone

from sqlalchemy import Boolean, Column, DateTime, Float, ForeignKey, Integer, String, Text

from .database import Base


def now():
    return datetime.now(timezone.utc).replace(tzinfo=None)


class User(Base):
    """Drivers, mechanics and parts suppliers share one table (role column)."""

    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    name = Column(String(120), nullable=False)
    email = Column(String(160), unique=True, index=True, nullable=False)
    phone = Column(String(40), default="")
    password_hash = Column(String(300), nullable=False)
    role = Column(String(20), default="driver")  # driver | mechanic | supplier
    business_name = Column(String(160), default="")
    address = Column(String(200), default="")
    lat = Column(Float, nullable=True)
    lng = Column(Float, nullable=True)
    specialization = Column(String(300), default="")  # comma separated categories
    services = Column(Text, default="")
    bio = Column(Text, default="")
    available = Column(Boolean, default=True)
    created_at = Column(DateTime, default=now)


class Vehicle(Base):
    __tablename__ = "vehicles"
    id = Column(Integer, primary_key=True)
    owner_id = Column(Integer, ForeignKey("users.id"), index=True, nullable=False)
    make = Column(String(60), nullable=False)
    model = Column(String(60), nullable=False)
    year = Column(Integer, default=2015)
    plate = Column(String(20), default="")
    vtype = Column(String(30), default="Car")


class Review(Base):
    __tablename__ = "reviews"
    id = Column(Integer, primary_key=True)
    mechanic_id = Column(Integer, ForeignKey("users.id"), index=True, nullable=False)
    driver_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    rating = Column(Integer, nullable=False)
    comment = Column(Text, default="")
    created_at = Column(DateTime, default=now)


class AssistanceRequest(Base):
    __tablename__ = "requests"
    id = Column(Integer, primary_key=True)
    driver_id = Column(Integer, ForeignKey("users.id"), index=True, nullable=False)
    vehicle_id = Column(Integer, ForeignKey("vehicles.id"), nullable=True)
    mechanic_id = Column(Integer, ForeignKey("users.id"), index=True, nullable=True)
    problem = Column(String(60), nullable=False)
    description = Column(Text, default="")
    lat = Column(Float, nullable=False)
    lng = Column(Float, nullable=False)
    status = Column(String(20), default="pending")  # pending|accepted|en_route|completed|cancelled
    created_at = Column(DateTime, default=now)
    updated_at = Column(DateTime, default=now)


class Message(Base):
    __tablename__ = "messages"
    id = Column(Integer, primary_key=True)
    request_id = Column(Integer, ForeignKey("requests.id"), index=True, nullable=False)
    sender_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    text = Column(Text, nullable=False)
    created_at = Column(DateTime, default=now)


class Part(Base):
    __tablename__ = "parts"
    id = Column(Integer, primary_key=True)
    supplier_id = Column(Integer, ForeignKey("users.id"), index=True, nullable=False)
    name = Column(String(120), nullable=False)
    category = Column(String(40), default="Engine")
    brand = Column(String(60), default="")
    price = Column(Integer, default=0)
    compatible = Column(String(200), default="")
    in_stock = Column(Boolean, default=True)
    location = Column(String(160), default="")
    created_at = Column(DateTime, default=now)
