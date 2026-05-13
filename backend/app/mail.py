from __future__ import annotations

import logging
import smtplib
from email.message import EmailMessage

from app.config import settings

logger = logging.getLogger(__name__)


def send_login_otp_email(email: str, code: str, expires_minutes: int) -> None:
    """Отправка кода входа (SMTP, stdout или no-op — см. MAIL_MODE)."""
    subject = "MediaLib — код для входа"
    body = (
        f"Ваш код подтверждения: {code}\n\n"
        f"Код действителен около {expires_minutes} минут.\n"
        "Если это были не вы, смените пароль."
    )
    _send_raw(email=email, subject=subject, body=body)


def send_profile_otp_email(email: str, code: str, expires_minutes: int, *, purpose_label: str) -> None:
    subject = f"MediaLib — код ({purpose_label})"
    body = (
        f"Ваш код: {code}\n\n"
        f"Действителен около {expires_minutes} минут.\n"
        f"Назначение: {purpose_label}."
    )
    _send_raw(email=email, subject=subject, body=body)


def _send_raw(*, email: str, subject: str, body: str) -> None:
    mode = settings.MAIL_MODE.lower().strip()
    if mode == "none":
        logger.info("MAIL_MODE=none: письмо не отправлено (получатель %s)", email)
        return
    if mode == "console":
        logger.warning(
            "MAIL_MODE=console: код отправлен только в лог (получатель=%s). Тема: %s",
            email,
            subject,
        )
        print(f"[MediaLib mail → {email}]\nSubject: {subject}\n\n{body}\n", flush=True)
        return
    if mode != "smtp":
        logger.warning("Неизвестный MAIL_MODE=%s, трактуем как console", mode)
        print(f"[MediaLib mail → {email}]\nSubject: {subject}\n\n{body}\n", flush=True)
        return

    host = settings.SMTP_HOST
    port = settings.SMTP_PORT
    user = settings.SMTP_USER
    password = settings.SMTP_PASSWORD
    mail_from = settings.MAIL_FROM
    if not host or not mail_from:
        logger.error("SMTP: задайте SMTP_HOST и MAIL_FROM")
        raise RuntimeError("Mail is not configured")

    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = mail_from
    msg["To"] = email
    msg.set_content(body)

    with smtplib.SMTP(host, port, timeout=30) as smtp:
        if settings.SMTP_USE_TLS:
            smtp.starttls()
        if user and password:
            smtp.login(user, password)
        smtp.send_message(msg)
