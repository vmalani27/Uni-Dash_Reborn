import os

os.environ.setdefault("USER_DATABASE_URL", "postgresql://user:pass@localhost/db")
os.environ.setdefault("CLIENT_ID", "test-client-id")
os.environ.setdefault("CLIENT_SECRET", "test-client-secret")
os.environ.setdefault("ENCRYPTION_KEY", "nN2TI__PwzmF1f_jpVlmmjiodjdd3iIdpbiO_z0ZW8Y=")
os.environ.setdefault("LOCAL_REDIRECT_URI", "http://localhost:8000/auth/google/callback")

from app.routers import oauth_routes


class FakeQuery:
    def __init__(self, session, model):
        self.session = session
        self.model = model

    def filter(self, *args, **kwargs):
        return self

    def first(self):
        return self.session.objects.get(self.model)


class FakeSession:
    def __init__(self, objects):
        self.objects = objects
        self.deleted = []
        self.commits = 0
        self.rollbacks = 0

    def query(self, model):
        return FakeQuery(self, model)

    def delete(self, obj):
        self.deleted.append(obj)
        for model, value in list(self.objects.items()):
            if value is obj:
                self.objects[model] = None

    def commit(self):
        self.commits += 1

    def rollback(self):
        self.rollbacks += 1


class Token:
    def __init__(self, refresh_token):
        self.refresh_token = refresh_token


class Status:
    def __init__(self):
        self.last_history_id = "history-123"
        self.watch_expiration = "2026-05-01T00:00:00Z"


class User:
    def __init__(self):
        self.oauth_connected = True
        self.reauth_required = True
        self.reauth_required_at = "2026-05-01T00:00:00Z"
        self.reauth_reason = "previous error"


def test_disconnect_stops_watch_and_clears_local_state(monkeypatch):
    token = Token("encrypted-refresh")
    status = Status()
    user = User()
    session = FakeSession(
        {
            oauth_routes.OAuthToken: token,
            oauth_routes.GmailSyncStatus: status,
            oauth_routes.User: user,
        }
    )

    stop_calls = {}

    def fake_stop(refresh_token, uid=None):
        stop_calls["refresh_token"] = refresh_token
        stop_calls["uid"] = uid
        return True

    monkeypatch.setattr(oauth_routes.GmailService, "stop_gmail_watch", staticmethod(fake_stop))
    monkeypatch.setattr(oauth_routes, "decrypt_token", lambda value: "plain-refresh")
    monkeypatch.setattr(oauth_routes, "_revoke_google_token", lambda refresh_token: True)

    response = oauth_routes.disconnect_google_account(
        firebase_data={"uid": "user-123"},
        db=session,
    )

    assert response == {
        "status": "disconnected",
        "gmail_watch_stopped": True,
        "google_revoked": True,
    }
    assert stop_calls == {"refresh_token": "plain-refresh", "uid": "user-123"}
    assert session.objects[oauth_routes.OAuthToken] is None
    assert status.last_history_id is None
    assert status.watch_expiration is None
    assert user.oauth_connected is False
    assert user.reauth_required is False
    assert user.reauth_required_at is None
    assert user.reauth_reason is None
    assert session.commits == 1
    assert session.rollbacks == 0


def test_disconnect_continues_when_watch_stop_fails(monkeypatch):
    token = Token("encrypted-refresh")
    status = Status()
    user = User()
    session = FakeSession(
        {
            oauth_routes.OAuthToken: token,
            oauth_routes.GmailSyncStatus: status,
            oauth_routes.User: user,
        }
    )

    def fake_stop(refresh_token, uid=None):
        return False

    monkeypatch.setattr(oauth_routes.GmailService, "stop_gmail_watch", staticmethod(fake_stop))
    monkeypatch.setattr(oauth_routes, "decrypt_token", lambda value: "plain-refresh")
    monkeypatch.setattr(oauth_routes, "_revoke_google_token", lambda refresh_token: True)

    response = oauth_routes.disconnect_google_account(
        firebase_data={"uid": "user-123"},
        db=session,
    )

    assert response == {
        "status": "disconnected",
        "gmail_watch_stopped": False,
        "google_revoked": True,
    }
    assert session.objects[oauth_routes.OAuthToken] is None
    assert status.last_history_id is None
    assert status.watch_expiration is None
    assert user.oauth_connected is False
    assert session.commits == 1
    assert session.rollbacks == 0
