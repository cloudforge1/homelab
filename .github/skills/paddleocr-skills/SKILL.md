---
name: paddleocr-skills
description: 'OCR document parsing and text recognition using PaddleOCR. Use when: OCR needed, document parsing, text recognition, PDF OCR, image text extraction.'
---

# PaddleOCR Skills

Meta-skill for OCR operations using PaddleOCR framework.

## Sub-skills

| Sub-skill | Purpose |
|-----------|---------|
| `paddleocr-doc-parsing/` | Full document parsing with layout analysis |
| `paddleocr-text-recognition/` | Text recognition from images/PDFs |

## When to Use

- Need to extract text from images or scanned documents
- Document parsing with layout preservation
- OCR for PDFs, scanned documents, or images
- Multi-language text recognition

## Quick Start

```bash
# Check if PaddleOCR service is running
cf health | grep paddle

# Use the OCR endpoint
curl -X POST http://localhost:<port>/ocr -F "file=@document.pdf"
```

## Reference

- See sub-skill directories for detailed procedures
- PaddleOCR service runs on cf0 homelab
