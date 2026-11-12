"""Demo data so the prototype looks alive on first launch."""
from sqlalchemy.orm import Session

from .config import SEED_LAT, SEED_LNG
from .models import Part, Review, User, Vehicle
from .security import hash_password

DEMO_PASSWORD = "demo1234"

# name, business, specialization, services, lat offset, lng offset, area, bio
MECHANICS = [
    ("Moses Kato", "Kato Auto Care", "Engine,Electrical",
     "Engine diagnostics, computer scanning, wiring repairs, full servicing",
     0.010, 0.030, "Ntinda", "Twelve years of experience on Japanese vehicles. Mobile service available."),
    ("Grace Namukasa", "QuickFix Tyre & Battery", "Tyres,Battery",
     "Puncture repair, tyre change, wheel balancing, battery testing and replacement",
     -0.012, 0.018, "Nakawa", "Fast roadside tyre and battery help, seven days a week."),
    ("Peter Ssemwogerere", "Ssemwogerere Motors", "Engine,Towing",
     "Engine overhaul, overheating repairs, towing to workshop",
     0.006, -0.020, "Wandegeya", "Family garage with its own tow truck."),
    ("Sarah Nabirye", "Bolt Roadside Rescue", "Towing,Battery",
     "24-hour towing, jump-start, fuel delivery",
     -0.025, 0.010, "Kansanga", "Quick response for breakdowns anywhere in Kampala."),
    ("David Okello", "Okello Auto Electrics", "Electrical,Engine",
     "Alternators, starters, lights, dashboard warning lights, ECU faults",
     0.020, -0.008, "Kawempe", "Specialist in car electrics and diagnostics."),
    ("Ruth Atim", "Atim Brake & Suspension", "Brakes,Tyres",
     "Brake pads and discs, shock absorbers, wheel alignment",
     -0.004, -0.015, "Kololo", "Safety-first brake and suspension repairs."),
    ("Joseph Mugisha", "Mugisha Mobile Mechanics", "Engine,Brakes,Electrical",
     "On-site diagnostics and minor repairs at your location",
     0.015, 0.012, "Bukoto", "We come to you - no towing needed for most faults."),
]

DRIVERS_EXTRA = ["Brian Ochieng", "Aisha Nakato", "Tom Wasswa"]

REVIEW_TEXT = [
    "Arrived quickly and fixed the problem on the spot.",
    "Honest pricing and very professional.",
    "Good service, explained everything clearly.",
    "Saved my day - came out after dark.",
    "Reliable and polite. Would call again.",
]
RATINGS = [(5, 5, 4), (4, 5, 5), (4, 4, 5), (5, 4, 5), (4, 5, 4), (5, 5, 5), (4, 4, 4)]

# name, category, brand, price (UGX), compatible with, shop index
PARTS = [
    ("Engine Oil 5W-30 (4L)", "Engine", "Castrol", 145000, "Most petrol engines", 0),
    ("Spark Plugs (set of 4)", "Engine", "NGK", 60000, "Toyota Premio, Allion, Corolla", 0),
    ("Fan Belt", "Engine", "Gates", 30000, "Toyota Harrier, RAV4", 1),
    ("Front Brake Pads", "Brakes", "Bosch", 85000, "Toyota Harrier, RAV4, Kluger", 0),
    ("Brake Disc (pair)", "Brakes", "Brembo", 260000, "Toyota Land Cruiser Prado", 1),
    ("Car Battery 12V 60Ah", "Battery", "Exide", 320000, "Most saloon cars and SUVs", 1),
    ("Car Battery 12V 100Ah", "Battery", "Amaron", 520000, "Pickups and large SUVs", 0),
    ("Tyre 195/65 R15", "Tyres", "Bridgestone", 210000, "Toyota Premio, Allion, Corolla", 0),
    ("Tyre 265/65 R17", "Tyres", "Dunlop", 380000, "Toyota Hilux, Prado", 1),
    ("Alternator", "Electrical", "Denso", 450000, "Toyota Premio, Allion", 1),
    ("Headlight Bulb H4", "Electrical", "Philips", 15000, "Universal", 0),
    ("Oil Filter", "Filters", "Toyota", 18000, "Toyota Premio, Allion, Corolla", 0),
    ("Air Filter", "Filters", "Denso", 25000, "Toyota Harrier, RAV4", 1),
    ("Radiator Coolant (5L)", "Cooling", "Prestone", 35000, "All vehicles", 1),
    ("Water Pump", "Cooling", "Aisin", 120000, "Toyota Premio, Allion", 0),
    ("Front Shock Absorber", "Suspension", "KYB", 180000, "Toyota Harrier, RAV4", 1),
]


def seed(db: Session) -> None:
    if db.query(User).count() > 0:
        return
    pw = hash_password(DEMO_PASSWORD)

    driver = User(name="Demo Driver", email="driver@demo.com", phone="+256700000001",
                  password_hash=pw, role="driver")
    db.add(driver)
    extra = []
    for i, name in enumerate(DRIVERS_EXTRA, start=1):
        u = User(name=name, email=f"driver{i}@autoassist.demo", phone=f"+25670000010{i}",
                 password_hash=pw, role="driver")
        db.add(u)
        extra.append(u)

    mechanics = []
    for i, m in enumerate(MECHANICS):
        name, biz, spec, services, dlat, dlng, area, bio = m
        u = User(
            name=name,
            email="mechanic@demo.com" if i == 0 else f"mechanic{i + 1}@autoassist.demo",
            phone=f"+2567000002{i:02d}",
            password_hash=pw,
            role="mechanic",
            business_name=biz,
            address=f"{area}, Kampala",
            lat=SEED_LAT + dlat,
            lng=SEED_LNG + dlng,
            specialization=spec,
            services=services,
            bio=bio,
            available=(i != 2),
        )
        db.add(u)
        mechanics.append(u)

    suppliers = []
    for i, (name, biz, area) in enumerate([
        ("Kisekka Spares", "Kisekka Spares", "Kisekka Market, Kampala"),
        ("Nakawa Auto Parts", "Nakawa Auto Parts", "Nakawa, Kampala"),
    ]):
        u = User(name=name, email="supplier@demo.com" if i == 0 else "supplier2@autoassist.demo",
                 phone=f"+2567000003{i:02d}", password_hash=pw, role="supplier",
                 business_name=biz, address=area, lat=SEED_LAT - 0.004 * i, lng=SEED_LNG + 0.006 * i)
        db.add(u)
        suppliers.append(u)

    db.flush()  # assigns ids

    db.add_all([
        Vehicle(owner_id=driver.id, make="Toyota", model="Premio", year=2012, plate="UBA 123A", vtype="Car"),
        Vehicle(owner_id=driver.id, make="Toyota", model="Hilux", year=2016, plate="UAX 456B", vtype="Pickup"),
    ])

    drivers = extra + [driver]
    for mi, mech in enumerate(mechanics):
        for di, d in enumerate(drivers[:3]):
            db.add(Review(mechanic_id=mech.id, driver_id=d.id, rating=RATINGS[mi][di],
                          comment=REVIEW_TEXT[(mi + di) % len(REVIEW_TEXT)]))

    for name, cat, brand, price, compat, shop in PARTS:
        s = suppliers[shop]
        db.add(Part(supplier_id=s.id, name=name, category=cat, brand=brand, price=price,
                    compatible=compat, in_stock=True, location=s.address))
    db.commit()
