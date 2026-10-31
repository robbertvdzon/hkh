-- Van welke bron een melding komt (bijvoorbeeld "macbook", "windows-laptop" of "hkh"), zodat het beheerscherm erop kan filteren.
ALTER TABLE workflow_login ADD COLUMN source VARCHAR(80);
ALTER TABLE workflow_session ADD COLUMN source VARCHAR(80);
CREATE INDEX workflow_login_source_idx ON workflow_login (source);
CREATE INDEX workflow_session_source_idx ON workflow_session (source);
