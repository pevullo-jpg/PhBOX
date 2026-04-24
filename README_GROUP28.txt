PHBOX - GROUP 28

Functional group completed:
- parser accuracy hardening using real prescription samples

Main changes:
- patient name extraction now prioritizes the explicit assistito block
- doctor name extraction now prioritizes the explicit medico block
- exemption detection now handles both coded exemption and NON ESENTE
- prescription date is now extracted from internal PDF text only
- when multiple internal dates are present, the parser keeps the latest labeled DATA found in the document
- city extraction improved for COMUNE / CITTA' / CAP + CITTA'
- fiscal code extraction now avoids taking the doctor's fiscal code
- medicine extraction remains limited to the prescription section

Files changed:
- lib/core/services/prescription_pdf_parser_service.dart

Notes:
- this improves the parser on the real samples provided in chat
- multi-prescription PDFs can still contain mixed data in one single intake; that requires a separate functional group for split/merge handling
