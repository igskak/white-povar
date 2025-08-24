# Recipe Ingestion System - User Guide

## Overview

The Recipe Ingestion System is an automated pipeline that converts unstructured recipe documents (TXT, DOC, DOCX, PDF) into structured recipe data in your database. It uses AI-powered parsing, validation, duplicate detection, and manual review workflows.

## Features

- **Automated File Processing**: Monitors a designated folder for new recipe documents
- **Multi-Format Support**: TXT, PDF, DOCX, and DOC files
- **AI-Powered Parsing**: Uses OpenAI to extract structured recipe data
- **Language Detection & Translation**: Automatically detects language and translates to English
- **Quality Validation**: Validates extracted data and calculates confidence scores
- **Duplicate Detection**: Prevents duplicate recipes using fingerprinting and fuzzy matching
- **Manual Review**: Flags low-confidence extractions for human review
- **Retry & Error Handling**: Automatic retries with exponential backoff
- **Admin Dashboard**: REST API endpoints for monitoring and management

## Quick Start

### 1. Install Dependencies

```bash
cd backend
pip install -r requirements-ingestion.txt
```

### 2. Set Environment Variables

Add to your `.env` file:

```env
OPENAI_API_KEY=your_openai_api_key_here
```

### 3. Run Database Migrations

Apply the new database schema:

```sql
-- Run the SQL commands from database_schema.sql
-- This adds ingestion_jobs, recipe_fingerprints, and ingestion_reviews tables
```

### 4. Start the Application

```bash
python -m uvicorn app.main:app --reload
```

The ingestion service will automatically start and create the necessary directories:
- `data/ingestion/inbox/` - Drop recipe files here
- `data/ingestion/processed/` - Successfully processed files
- `data/ingestion/failed/` - Failed files
- `data/ingestion/dlq/` - Dead letter queue for max retries exceeded

## How to Use

### Method 1: File Drop (Automatic)

1. Save recipe documents to `data/ingestion/inbox/`
2. The system automatically detects and processes new files
3. Check processing status via API endpoints

### Method 2: Upload via API (Manual)

```bash
curl -X POST "http://localhost:8000/api/v1/ingestion/upload" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "file=@recipe.pdf"
```

## API Endpoints

### Get Service Status
```
GET /api/v1/ingestion/status
```

### List Ingestion Jobs
```
GET /api/v1/ingestion/jobs?status=NEEDS_REVIEW&limit=20
```

### Get Specific Job
```
GET /api/v1/ingestion/jobs/{job_id}
```

### Review a Job
```
POST /api/v1/ingestion/jobs/{job_id}/review
{
  "decision": "APPROVED",
  "notes": "Recipe looks good"
}
```

### Reprocess Failed Job
```
POST /api/v1/ingestion/jobs/{job_id}/reprocess
```

### Get Statistics
```
GET /api/v1/ingestion/stats
```

## Job Statuses

- **PENDING**: Waiting to be processed
- **PROCESSING**: Currently being processed
- **NEEDS_REVIEW**: Requires manual review (low confidence or issues)
- **COMPLETED**: Successfully processed and recipe created
- **COMPLETED_DUPLICATE**: Identified as duplicate of existing recipe
- **FAILED**: Processing failed (will retry)
- **DLQ**: Dead letter queue (max retries exceeded)

## Manual Review Process

When a recipe needs manual review:

1. Check jobs with `NEEDS_REVIEW` status
2. Review the parsed recipe data in the job's `meta` field
3. Make a decision:
   - **APPROVED**: Create the recipe as-is
   - **REJECTED**: Reject the recipe with reason
   - **NEEDS_REVISION**: Send back for reprocessing

## Configuration

### Environment Variables

```env
# Required
OPENAI_API_KEY=your_openai_api_key

# Optional (with defaults)
INGESTION_WORKERS=2
INGESTION_BASE_PATH=data/ingestion
INGESTION_MAX_RETRIES=3
INGESTION_CONFIDENCE_THRESHOLD=0.75
```

### Supported File Formats

- **TXT**: Plain text files (UTF-8 or Latin-1)
- **PDF**: Portable Document Format
- **DOCX**: Microsoft Word (modern format)
- **DOC**: Microsoft Word (legacy format, requires textract)

## Troubleshooting

### Common Issues

1. **OpenAI API Errors**
   - Check API key is valid
   - Verify account has sufficient credits
   - Monitor rate limits

2. **File Processing Failures**
   - Ensure file is not corrupted
   - Check file format is supported
   - Verify file permissions

3. **Low Confidence Scores**
   - Review recipe text quality
   - Check for OCR artifacts
   - Ensure text is in supported language

### Logs

Check application logs for detailed error information:
```bash
tail -f logs/app.log
```

### Monitoring

Use the stats endpoint to monitor pipeline health:
- Success rate should be > 80%
- Review rate should be < 30%
- DLQ size should remain low

## Advanced Features

### Custom Chef Styles

The AI parser can be configured to match specific chef writing styles by providing examples in the prompt. Modify `ai_parser.py` to include chef-specific style guidelines.

### Batch Processing

For large volumes of files:

1. Place all files in the inbox directory
2. The system will process them automatically
3. Monitor progress via the stats endpoint

### Duplicate Detection Tuning

Adjust similarity thresholds in `dedupe.py`:
- `similarity_threshold`: Controls fuzzy matching sensitivity
- `time_tolerance_minutes`: Time difference tolerance for similar recipes

## Performance Optimization

### Scaling

- Increase `INGESTION_WORKERS` for higher throughput
- Use Redis/Celery for distributed processing
- Implement Supabase Storage events for cloud deployments

### Cost Optimization

- Use `gpt-4o-mini` for cost-effective parsing
- Implement caching for repeated extractions
- Batch similar recipes for processing

## Security Considerations

- Validate file types and sizes
- Scan uploaded files for malware
- Implement rate limiting on upload endpoints
- Use signed URLs for cloud storage

## Backup and Recovery

- Ingestion jobs are tracked in the database
- Original files are preserved in processed/failed directories
- Failed jobs can be reprocessed from the admin interface

## Testing

Run the test suite to verify everything is working:

```bash
python test_ingestion.py
```

This will test:
- Text extraction from files
- Language detection
- AI parsing (requires OpenAI API key)
- Recipe validation
- Duplicate detection

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review application logs
3. Use the admin API to inspect job details
4. Run the test suite to identify issues
5. Contact the development team with job IDs for specific issues
