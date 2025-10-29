# Genwise Security Setup

## Google Cloud Credentials

The Google Cloud service account credentials file was removed from the repository for security reasons. To set up the credentials:

### Option 1: Local Development

1. Download your service account key from Google Cloud Console
2. Save it as `assets/true-elevator-451713-h5-61c14c2cd65a.json` (this file is already in .gitignore)
3. Make sure never to commit this file to git

### Option 2: Environment Variables (Recommended for Production)

Instead of using a JSON file, you can set up the credentials using environment variables:

```bash
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/your/credentials.json"
```

Or set individual environment variables:

```bash
export GOOGLE_CLOUD_PROJECT_ID="your-project-id"
export GOOGLE_CLOUD_PRIVATE_KEY="your-private-key"
export GOOGLE_CLOUD_CLIENT_EMAIL="your-client-email"
```

### Option 3: Firebase Admin SDK (Flutter Web/Mobile)

For Flutter applications, consider using Firebase Admin SDK or Firebase Auth instead of service account keys.

## Important Security Notes

- Never commit credentials files to version control
- Use environment variables or secure secret management services in production
- Regularly rotate your service account keys
- Follow the principle of least privilege when setting up service accounts

## Files Already Protected

The following sensitive files are now in .gitignore:

- `**/*.json` (all JSON files in assets)
- `assets/true-elevator-451713-h5-61c14c2cd65a.json`
- `.env` files
- Firebase debug logs
