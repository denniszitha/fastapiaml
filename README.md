# AML Transaction Monitoring System - FastAPI

A comprehensive Anti-Money Laundering (AML) transaction monitoring system built with FastAPI, providing real-time transaction analysis, risk scoring, and suspicious activity detection.

## Features

- **Real-time Transaction Monitoring**: Process transactions via webhook endpoints
- **Risk Scoring Engine**: Automated risk assessment based on multiple factors
- **Watchlist Management**: Track and monitor high-risk accounts
- **Transaction Exemptions**: Manage exempted accounts
- **Configurable Limits**: Set transaction thresholds by channel and type
- **Customer Profiling**: Maintain and update customer risk profiles
- **Suspicious Case Management**: Track and manage suspicious transactions
- **RESTful API**: Complete API with automatic documentation

## Tech Stack

- **FastAPI**: Modern, fast web framework for building APIs
- **SQLAlchemy**: SQL toolkit and ORM
- **PostgreSQL**: Database (configurable)
- **Pydantic**: Data validation using Python type annotations
- **Uvicorn**: ASGI server

## Installation

1. Clone the repository:
```bash
cd fastapi-aml-monitoring
```

2. Create a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. Install dependencies:
```bash
pip install -r requirements.txt
```

4. Set up environment variables:
```bash
cp .env.example .env
# Edit .env with your configuration
```

5. Initialize the database:
```bash
alembic init alembic
alembic revision --autogenerate -m "Initial migration"
alembic upgrade head
```

## Running the Application

### Development
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 50000
```

### Production
```bash
uvicorn app.main:app --host 0.0.0.0 --port 50000 --workers 4
```

## API Documentation

Once running, access the interactive API documentation at:
- Swagger UI: `http://localhost:50000/docs`
- ReDoc: `http://localhost:50000/redoc`

## API Endpoints

### Transaction Monitoring
- `POST /api/v1/webhook/suspicious` - Process suspicious transaction
- `GET /api/v1/monitoring/status` - Get monitoring system status
- `POST /api/v1/monitoring/toggle` - Enable/disable monitoring

### Watchlist Management
- `POST /api/v1/watchlist` - Add account to watchlist
- `GET /api/v1/watchlist` - Get watchlist entries
- `DELETE /api/v1/watchlist/{account_number}` - Remove from watchlist

### Exemptions
- `POST /api/v1/exemptions` - Add transaction exemption
- `GET /api/v1/exemptions` - Get exemptions
- `DELETE /api/v1/exemptions/{account_number}` - Remove exemption

### Transaction Limits
- `POST /api/v1/limits` - Create/update transaction limit
- `GET /api/v1/limits` - Get transaction limits

### Customer Profiles
- `GET /api/v1/profiles/{account_number}` - Get customer profile

### Suspicious Cases
- `GET /api/v1/suspicious-cases` - List suspicious cases
- `GET /api/v1/suspicious-cases/{case_number}` - Get specific case
- `PATCH /api/v1/suspicious-cases/{case_number}/status` - Update case status

## Transaction Processing Flow

1. **Webhook Receipt**: Transaction data received via webhook
2. **Exemption Check**: Verify if account is exempted
3. **Risk Assessment**: Calculate risk score based on multiple factors
4. **Threshold Check**: Compare against configured limits
5. **Watchlist Check**: Verify if account is on watchlist
6. **Profile Update**: Update customer risk profile
7. **Case Creation**: Create suspicious case if flagged
8. **External Sync**: Optional sync to external systems
9. **AI Analysis**: Optional queue for AI processing

## Configuration

Key configuration options in `.env`:

- `DATABASE_URL`: PostgreSQL connection string
- `WEBHOOK_TOKEN`: Security token for webhook validation
- `MONITORING_ENABLED`: Enable/disable transaction monitoring
- `ENABLE_AI_ANALYSIS`: Enable AI analysis queue
- `ENABLE_EXTERNAL_SYNC`: Enable external API sync

## Database Schema

The system uses the following main tables:
- `suspicious_cases`: Flagged transactions
- `transactions`: All processed transactions
- `customer_profiles`: Customer risk profiles
- `raw_transactions`: Raw transaction data
- `watchlists`: Monitored accounts
- `transaction_exemptions`: Exempted accounts
- `transaction_limits`: Threshold configurations

## Security

- Webhook token validation
- JWT authentication support (for future implementation)
- Password hashing with bcrypt
- CORS configuration
- Environment-based configuration

## Testing

Run tests with:
```bash
pytest
```

## Docker Support

Build and run with Docker:
```bash
docker build -t aml-monitoring .
docker run -p 50000:50000 --env-file .env aml-monitoring
```

## Monitoring and Logging

- Configurable log levels
- Structured logging
- Health check endpoint at `/health`

## License

[Your License Here]

## Support

For issues and questions, please contact the development team.