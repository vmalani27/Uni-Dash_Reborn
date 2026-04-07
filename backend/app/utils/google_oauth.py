import os
import requests


class OAuthRefreshError(RuntimeError):
    """Generic OAuth refresh failure."""


class OAuthReauthRequiredError(OAuthRefreshError):
    """Refresh token is revoked/expired and user must reconnect OAuth."""

# Retrieve OAuth client credentials from environment variables.
# These must be set for token refresh to work. If they are missing, we raise a clear error.
CLIENT_ID = os.getenv("CLIENT_ID")
CLIENT_SECRET = os.getenv("CLIENT_SECRET")

if not CLIENT_ID or not CLIENT_SECRET:
    # Provide a detailed message to aid debugging.
    raise RuntimeError(
        "Google OAuth client credentials are not configured. "
        "Set the CLIENT_ID and CLIENT_SECRET environment variables."
    )


def get_access_token(refresh_token: str) -> str:
    """Exchange a refresh token for a new access token.

    Raises:
        RuntimeError: If the request fails or the response does not contain an
            ``access_token``. The error message includes the HTTP status code and
            any error details returned by Google.
    """

    # Debug output – can be removed or replaced with proper logging.
    print(f"Requesting access token with CLIENT_ID={CLIENT_ID}")
    try:
        resp = requests.post(
            "https://oauth2.googleapis.com/token",
            data={
                "client_id": CLIENT_ID,
                "client_secret": CLIENT_SECRET,
                "refresh_token": refresh_token,
                "grant_type": "refresh_token",
            },
            timeout=10,
        )
        resp.raise_for_status()
    except requests.exceptions.HTTPError as e:
        # Include response body for easier debugging.
        try:
            error_detail = resp.json()
        except Exception:
            error_detail = resp.text
        if isinstance(error_detail, dict) and error_detail.get("error") == "invalid_grant":
            raise OAuthReauthRequiredError(
                "Google OAuth refresh token is invalid_grant (expired or revoked). "
                "User must reconnect Gmail OAuth."
            ) from e

        raise OAuthRefreshError(
            f"Failed to refresh Google OAuth token (status {resp.status_code}): {error_detail}"
        ) from e
    except Exception as e:
        raise OAuthRefreshError(f"Unexpected error while refreshing token: {e}") from e

    data = resp.json()
    if "access_token" not in data:
        raise OAuthRefreshError(
            f"Google token response missing 'access_token': {data}"
        )
    return data["access_token"]
