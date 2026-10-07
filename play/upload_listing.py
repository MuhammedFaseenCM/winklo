"""Upload Play Store listing text and graphics via the Android Publisher API.

Fastlane supply cannot update a listing until a binary release exists.
This script writes listing copy and images through an edit, which works
on a newly created Play Console app.
"""

from __future__ import annotations

import sys
import time
from pathlib import Path

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaFileUpload

ROOT = Path(__file__).resolve().parents[1]
PACKAGE_NAME = "com.winklo.faseencm"
LANGUAGE = "en-US"
JSON_KEY = ROOT / "play/play-service-account.json"
METADATA = ROOT / "fastlane/metadata/android" / LANGUAGE
IMAGES = METADATA / "images"
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]


def _read(name: str) -> str:
  return (METADATA / name).read_text(encoding="utf-8").strip()


def _execute_with_retry(request, max_attempts: int = 5):
  for attempt in range(1, max_attempts + 1):
    try:
      return request.execute()
    except HttpError as error:
      if error.resp.status in (429, 500, 502, 503, 504) and attempt < max_attempts:
        sleep_time = 2 ** attempt
        print(
            f"Transient HTTP {error.resp.status}, retrying in {sleep_time}s"
            f" (attempt {attempt}/{max_attempts})...",
            file=sys.stderr,
        )
        time.sleep(sleep_time)
        continue
      raise


def _delete_images(service, edit_id: str, image_type: str) -> None:
  try:
    _execute_with_retry(
        service.edits().images().deleteall(
            packageName=PACKAGE_NAME,
            editId=edit_id,
            language=LANGUAGE,
            imageType=image_type,
        )
    )
  except HttpError as error:
    if error.resp.status != 404:
      raise


def _upload_image(service, edit_id: str, image_type: str, path: Path) -> None:
  media = MediaFileUpload(str(path), mimetype="image/png", resumable=False)
  _execute_with_retry(
      service.edits().images().upload(
          packageName=PACKAGE_NAME,
          editId=edit_id,
          language=LANGUAGE,
          imageType=image_type,
          media_body=media,
      )
  )


def main() -> int:
  if not JSON_KEY.is_file():
    print(f"Missing service account key: {JSON_KEY}", file=sys.stderr)
    return 1

  credentials = service_account.Credentials.from_service_account_file(
      JSON_KEY,
      scopes=SCOPES,
  )
  service = build("androidpublisher", "v3", credentials=credentials)
  insert_req = service.edits().insert(packageName=PACKAGE_NAME, body={})
  edit_id = _execute_with_retry(insert_req)["id"]

  listing = {
      "language": LANGUAGE,
      "title": _read("title.txt"),
      "shortDescription": _read("short_description.txt"),
      "fullDescription": _read("full_description.txt"),
  }
  video_path = METADATA / "video.txt"
  if video_path.is_file():
    listing["video"] = video_path.read_text(encoding="utf-8").strip()
  _execute_with_retry(
      service.edits().listings().update(
          packageName=PACKAGE_NAME,
          editId=edit_id,
          language=LANGUAGE,
          body=listing,
      )
  )
  print(f"Updated {LANGUAGE} listing: {listing['title']}")
  if "video" in listing:
    print(f"Promo video: {listing['video']}")

  icon = IMAGES / "icon.png"
  feature = IMAGES / "featureGraphic.png"
  screenshots = sorted((IMAGES / "phoneScreenshots").glob("*.png"))
  if icon.is_file():
    _delete_images(service, edit_id, "icon")
    _upload_image(service, edit_id, "icon", icon)
    print(f"Uploaded icon ({icon.stat().st_size} bytes)")
  if feature.is_file():
    _delete_images(service, edit_id, "featureGraphic")
    _upload_image(service, edit_id, "featureGraphic", feature)
    print(f"Uploaded feature graphic ({feature.stat().st_size} bytes)")
  if screenshots:
    _delete_images(service, edit_id, "phoneScreenshots")
    for path in screenshots:
      _upload_image(service, edit_id, "phoneScreenshots", path)
      print(f"Uploaded screenshot {path.name} ({path.stat().st_size} bytes)")

  _execute_with_retry(
      service.edits().commit(packageName=PACKAGE_NAME, editId=edit_id)
  )
  print("Committed Play Store listing edit.")
  return 0


if __name__ == "__main__":
  raise SystemExit(main())
