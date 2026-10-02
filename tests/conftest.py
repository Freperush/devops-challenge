import os

os.environ["API_KEY"] = "2f5ae96c-b558-4c7b-a590-a501ae1c3f6c"
os.environ["JWT_SECRET"] = "test-secret-test-secret-test-sec"

API_KEY = os.environ["API_KEY"]
JWT_SECRET = os.environ["JWT_SECRET"]
VALID_BODY = {
    "message": "This is a test",
    "to": "Juan Perez",
    "from": "Rita Asturia",
    "timeToLifeSec": 45,
}
