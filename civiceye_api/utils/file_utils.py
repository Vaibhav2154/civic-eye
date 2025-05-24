import shutil
import tempfile

async def save_upload_file_tmp(upload_file):
    suffix = f"_{upload_file.filename}"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        shutil.copyfileobj(upload_file.file, tmp)
        return tmp.name