from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    database_url: str
    password: str
    photos_dir: str = "photos"
    host: str = "0.0.0.0"
    port: int = 8000


settings = Settings()
