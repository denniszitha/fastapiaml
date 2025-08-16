"""
Enhanced CORS Middleware that handles all CORS scenarios
"""
from fastapi import Request
from fastapi.responses import Response
import logging

logger = logging.getLogger(__name__)

async def cors_middleware(request: Request, call_next):
    """
    Middleware to handle CORS for all requests
    """
    # Get the origin from the request
    origin = request.headers.get("origin")
    
    # Log the request for debugging
    logger.info(f"Request: {request.method} {request.url.path} from origin: {origin}")
    
    # Handle preflight OPTIONS requests immediately
    if request.method == "OPTIONS":
        response = Response()
        response.status_code = 200
        
        # Set permissive CORS headers for OPTIONS
        response.headers["Access-Control-Allow-Origin"] = origin or "*"
        response.headers["Access-Control-Allow-Credentials"] = "true"
        response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS, PATCH, HEAD"
        response.headers["Access-Control-Allow-Headers"] = "*"
        response.headers["Access-Control-Max-Age"] = "86400"  # 24 hours
        
        logger.info(f"OPTIONS request handled for {request.url.path}")
        return response
    
    # Process the actual request
    response = await call_next(request)
    
    # Add CORS headers to all responses
    if origin:
        response.headers["Access-Control-Allow-Origin"] = origin
        response.headers["Access-Control-Allow-Credentials"] = "true"
        response.headers["Access-Control-Expose-Headers"] = "*"
        response.headers["Vary"] = "Origin"
    
    return response