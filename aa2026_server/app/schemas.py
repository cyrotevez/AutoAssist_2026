from typing import List, Optional

from pydantic import BaseModel, Field


class RegisterIn(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    email: str = Field(min_length=5, max_length=160)
    password: str = Field(min_length=6, max_length=100)
    phone: str = ""
    role: str = "driver"
    business_name: str = ""


class LoginIn(BaseModel):
    email: str
    password: str


class ProfileIn(BaseModel):
    name: Optional[str] = None
    phone: Optional[str] = None
    business_name: Optional[str] = None
    address: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    specialization: Optional[str] = None
    services: Optional[str] = None
    bio: Optional[str] = None
    available: Optional[bool] = None


class VehicleIn(BaseModel):
    make: str = Field(min_length=1, max_length=60)
    model: str = Field(min_length=1, max_length=60)
    year: int = Field(ge=1950, le=2100)
    plate: str = ""
    vtype: str = "Car"


class RequestIn(BaseModel):
    problem: str = Field(min_length=2, max_length=60)
    description: str = ""
    lat: float
    lng: float
    vehicle_id: Optional[int] = None
    mechanic_id: Optional[int] = None


class StatusIn(BaseModel):
    status: str


class MessageIn(BaseModel):
    text: str = Field(min_length=1, max_length=2000)


class ReviewIn(BaseModel):
    rating: int = Field(ge=1, le=5)
    comment: str = ""


class PartIn(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    category: str = "Engine"
    brand: str = ""
    price: int = Field(default=0, ge=0)
    compatible: str = ""
    in_stock: bool = True
    location: str = ""


class StockIn(BaseModel):
    in_stock: bool


class ChatMsg(BaseModel):
    role: str
    content: str


class AiIn(BaseModel):
    messages: List[ChatMsg]
    vehicle: Optional[str] = None
