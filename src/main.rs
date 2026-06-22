use axum::{
    extract::State,
    http::StatusCode,
    response::IntoResponse,
    routing::post,
    Json, Router,
};
use lingua::{Language, LanguageDetector, LanguageDetectorBuilder};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::net::TcpListener;

#[derive(Deserialize)]
pub struct DetectRequest {
    pub text: String,
}

#[derive(Serialize)]
pub struct DetectResponse {
    pub language: String,
    pub is_reliable: bool,
}

pub struct AppState {
    detector: LanguageDetector,
}

async fn detect_language(
    State(state): State<Arc<AppState>>,
    Json(payload): Json<DetectRequest>,
) -> impl IntoResponse {
    if payload.text.trim().is_empty() {
        return (
            StatusCode::BAD_REQUEST,
            Json(serde_json::json!({ "error": "O texto não pode ser vazio" })),
        ).into_response();
    }

    let result = state.detector.detect_language_of(&payload.text);

    match result {
        Some(language) => {
            let response = DetectResponse {
                // Extrai o ISO 639-1 (ex: "EN", "PT") e converte para minúsculo
                language: language.iso_code_639_1().to_string().to_lowercase(),
                is_reliable: true,
            };
            (StatusCode::OK, Json(serde_json::json!(response))).into_response()
        }
        None => {
            let response = DetectResponse {
                // O LibreTranslate utiliza "auto" para detecção automática ou quando o idioma é desconhecido
                language: "auto".to_string(),
                is_reliable: false,
            };
            (StatusCode::OK, Json(serde_json::json!(response))).into_response()
        }
    }
}

#[tokio::main]
async fn main() {
    println!("Iniciando o build do Language Detector...");

    let detector = LanguageDetectorBuilder::from_all_languages().build();
    
    let shared_state = Arc::new(AppState { detector });

    let app = Router::new()
        .route("/api/v1/detect", post(detect_language))
        .with_state(shared_state);

    let port = "3000";
    let listener = TcpListener::bind(format!("0.0.0.0:{}", port))
        .await
        .unwrap();

    println!("Microsserviço rodando na porta {}", port);
    
    axum::serve(listener, app).await.unwrap();
}   