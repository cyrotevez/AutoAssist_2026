import base64
import hashlib
import hmac
import os
from datetime import timedelta
from typing import Optional

import jwt
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from .config import SECRET_KEY, TOKEN_DAYS
from .database import get_db
from .models import User, now

bearer = HTTPBearer(auto_error=False)
ITERATIONS = 120_000


def hash_password(password: str) -> str:
    salt = os.urandom(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, ITERATIONS)
    return base64.b64encode(salt).decode() + "$" + base64.b64encode(digest).decode()


def verify_password(password: str, stored: str) -> bool:
    try:
        salt_b64, digest_b64 = stored.split("$")
        salt = base64.b64decode(salt_b64)
        expected = base64.b64decode(digest_b64)
    except Exception:
        return False
    digest = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, ITERATIONS)
    return hmac.compare_digest(digest, expected)


def create_token(user_id: int) -> str:
    payload = {"sub": str(user_id), "exp": now() + timedelta(days=TOKEN_DAYS)}
    return jwt.encode(payload, SECRET_KEY, algorithm="HS256")


def decode_token(token: str) -> Optional[int]:
    try:
        data = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
        return int(data["sub"])
    except Exception:
        return None


def current_user(
    creds: Optional[HTTPAuthorizationCredentials] = Depends(bearer),
    db: Session = Depends(get_db),
) -> User:
    if creds is None:
        raise HTTPException(status_code=401, detail="Please log in to continue.")
    uid = decode_token(creds.credentials)
    user = db.get(User, uid) if uid else None
    if user is None:
        raise HTTPException(status_code=401, detail="Your session has expired. Please log in again.")
    return user
