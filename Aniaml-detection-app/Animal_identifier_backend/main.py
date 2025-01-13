import cloudinary
import cloudinary.uploader
from fastapi import FastAPI, File, UploadFile, Form
from fastapi.responses import JSONResponse
import tensorflow as tf
from datetime import datetime
from dotenv import load_dotenv
from tensorflow.keras.models import load_model
from pydantic import BaseModel
import numpy as np
import cv2
import pandas as pd
import pyodbc
import os
from io import BytesIO
import uuid

# FastAPI uygulaması
app = FastAPI()

# .env dosyasını yükle
load_dotenv()

# Modeli yükleme
MODEL_PATH = "animal_detection_model.h5"
model = load_model(MODEL_PATH)

# Cloudinary API ayarları
cloudinary.config(
    cloud_name=os.getenv("CLOUDINARY_CLOUD_NAME"),
    api_key=os.getenv("CLOUDINARY_API_KEY"),
    api_secret=os.getenv("CLOUDINARY_API_SECRET")
)

# MSSQL veritabanı bağlantısı
DATABASE_CONFIG = {
    "server": os.getenv("DB_SERVER"),
    "database": os.getenv("DB_DATABASE"),
    "username": os.getenv("DB_USERNAME"),
    "password": os.getenv("DB_PASSWORD"),
}

connection_string = (
    f"DRIVER={{ODBC Driver 18 for SQL Server}};"
    f"SERVER={DATABASE_CONFIG['server']};"
    f"DATABASE={DATABASE_CONFIG['database']};"
    f"UID={DATABASE_CONFIG['username']};"
    f"PWD={DATABASE_CONFIG['password']};"
    "TrustServerCertificate=yes;"
)
conn = pyodbc.connect(connection_string)
cursor = conn.cursor()

# Flutter'dan gelen resim ve device_id ile API endpoint'i

from fastapi.responses import JSONResponse
from tempfile import NamedTemporaryFile
import os

@app.post("/predict/")
async def predict(
    device_id: str = Form(...),
    file: UploadFile = File(...),
):
    try:
        # Resmi yükleme
        contents = await file.read()
        if not contents:
            return {"error": "Uploaded file is empty!"}

        # Görüntüyü işleme
        try:
            nparr = np.frombuffer(contents, np.uint8)
            img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            img = cv2.resize(img, (224, 224))
            img = img / 255.0
            img = np.expand_dims(img, axis=0)
        except Exception as e:
            return {"error": f"Image processing error: {str(e)}"}

        # Model ile tahmin
        try:
            predictions = model.predict(img)
            predicted_class = int(np.argmax(predictions[0]))
            confidence = float(np.max(predictions[0]))
        except Exception as e:
            return {"error": f"Model prediction error: {str(e)}"}

        # MSSQL sorgusu
        try:
            query = "SELECT * FROM Animals WHERE ModelIndex = ?"
            cursor.execute(query, (predicted_class,))
            db_result = cursor.fetchone()
        except Exception as e:
            return {"error": f"Database query error: {str(e)}"}

        # Geçici dosya oluşturma
        try:
            with NamedTemporaryFile(delete=False, suffix=".jpg") as temp_file:
                temp_file.write(contents)
                temp_file_path = temp_file.name
        except Exception as e:
            return {"error": f"Temporary file creation error: {str(e)}"}

        # Cloudinary'e yükleme yap
        try:
            upload_result = cloudinary.uploader.upload(
                temp_file_path,
                folder="AnimalIdentity",
                resource_type="image",
                use_filename=True,
                unique_filename=False
            )
            image_url = upload_result.get("secure_url")
        except Exception as e:
            return {"error": f"Cloudinary upload error: {str(e)}"}
        finally:
            # Geçici dosyayı sil
            if os.path.exists(temp_file_path):
                os.remove(temp_file_path)

        # Veritabanına geçmiş ekleme
        try:
            insert_query = """
                INSERT INTO Histories (DeviceId, AnimalId, ImageURL)
                VALUES (?, ?, ?)
            """
            cursor.execute(insert_query, (device_id, db_result[0], image_url))
            conn.commit()
        except Exception as e:
            return {"error": f"Database insertion error: {str(e)}"}

        # Başarılı sonucu döndür
        isSuccess = True
        info_json = {
            "Name": db_result[1],         # Hayvan adı
            "Nutrition": db_result[2],    # Beslenme bilgisi
            "Habitat": db_result[3],      # Yaşam alanı bilgisi
            "Reproduction": db_result[4], # Üreme bilgisi
            "Confidence": confidence,     # Modelin güven skoru
        }
        return JSONResponse(
            content={
                "isSuccess": isSuccess,
                "data": info_json,
                "error": None,
            }
        )

    except Exception as e:
        return JSONResponse(
            content={
                "isSuccess": False,
                "data": None,
                "error": f"Unexpected error: {str(e)}",
            },
            status_code=500,
        )



@app.get("/histories/{device_id}")
async def get_histories(device_id: str):
    try:

        query = """
                   SELECT h.DeviceId, h.AnimalId, a.Name, a.Nutrition, a.Habitat, a.Reproduction, h.CreatedAt, h.ImageURL
                   FROM Histories h
                   INNER JOIN Animals a ON h.AnimalId = a.Id
                   WHERE h.DeviceId = ?
                   ORDER BY h.CreatedAt DESC
               """
        cursor.execute(query, (device_id,))
        rows = cursor.fetchall()

        histories = []
        for row in rows:
            histories.append({
                "DeviceId": row[0],
                "AnimalId": row[1],
                "AnimalName": row[2],
                "Nutrition": row[3],
                "Habitat": row[4],
                "Reproduction": row[5],
                "CreatedAt": row[6].isoformat() if isinstance(row[6], datetime) else str(row[6]),
                "ImageURL": row[7]
            })

        return JSONResponse(
            content={
                "isSuccess": True,
                "data": histories,
                "error": None
            }
        )

    except Exception as e:
        return JSONResponse(
            content={
                "isSuccess": False,
                "data": None,
                "error": str(e)
            },
            status_code=500
        )