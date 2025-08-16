"""
Custom CORS middleware for handling preflight requests
"""
from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
import logging

logger = logging.getLogger(__name__)

class CORSMiddleware(BaseHTTPMiddleware):
    """
    Custom CORS middleware to handle preflight OPTIONS requests
    """
    
    async def dispatch(self, request: Request, call_next):
        # Log the request for debugging
        logger.debug(f"Incoming request: {request.method} {request.url.path}")
        logger.debug(f"Origin header: {request.headers.get('origin', 'No origin header')}")
        
        # Handle preflight OPTIONS requests
        if request.method == "OPTIONS":
            response = Response()
            response.headers["Access-Control-Allow-Origin"] = request.headers.get("origin", "*")
            response.headers["Access-Control-Allow-Credentials"] = "true"
            response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS, PATCH, HEAD"
            response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-Requested-With, Accept, Origin, Access-Control-Request-Method, Access-Control-Request-Headers"
            response.headers["Access-Control-Max-Age"] = "3600"
            return response
        
        # Process the actual request
        response = await call_next(request)
        
        # Add CORS headers to the response
        origin = request.headers.get("origin")
        if origin:
            response.headers["Access-Control-Allow-Origin"] = origin
            response.headers["Access-Control-Allow-Credentials"] = "true"
            response.headers["Access-Control-Expose-Headers"] = "Content-Disposition, Content-Length, X-Request-ID"
        
        return response