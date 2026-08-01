# Friends mini-program

Friends is a QR invitation test application for the Flutter mini-program
platform. It uses Cognito authentication and an artifact-owned Publisher API.

The relationship workflow is deliberately explicit:

1. One signed-in user creates a five-minute, single-use QR invitation.
2. Another signed-in user scans it and creates a pending request.
3. The invited user accepts or declines that request.
4. Only acceptance creates the symmetric friendship records.

QR values are inert data. The application never opens scanned URLs, and the
backend stores only a SHA-256 hash of each invitation token.
