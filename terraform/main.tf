# =============================================================================
# Model Armor Red Team — Infrastructure
# Author  : Megh Shetty
# Purpose : Deploy Model Armor floor settings and tiered confidence templates
#           for adversarial AI security testing via the C0D3X agent
# Repo    : github.com/MeghvShetty/model-armor-redteam
# =============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

# =============================================================================
# Variables
# =============================================================================

variable "billing_account" {
  description = "GCP billing account ID"
  type        = string
  default     = "" # Please add billing value
  sensitive   = true
}

variable "region" {
  description = "GCP region for Model Armor templates"
  type        = string
  default     = "europe-west4"
}

# =============================================================================
# Project Bootstrap
# =============================================================================

resource "random_id" "project_suffix" {
  byte_length = 2
}

resource "google_project" "model_armor_c0d3x" {
  name            = "model-armor-c0d3x"
  project_id      = "model-armor-c0d3x-${random_id.project_suffix.hex}"
  billing_account = var.billing_account
  deletion_policy = "DELETE"

  lifecycle {
    ignore_changes = [billing_account]
  }
}

resource "google_billing_project_info" "project_billing" {
  project         = google_project.model_armor_c0d3x.project_id
  billing_account = var.billing_account
}

# Billing propagation buffer — GCP requires ~2 min before APIs can be enabled
resource "time_sleep" "wait_for_billing" {
  depends_on      = [google_billing_project_info.project_billing]
  create_duration = "300s"
}

# =============================================================================
# API Enablement
# =============================================================================

resource "google_project_service" "modelarmor_api" {
  project            = google_project.model_armor_c0d3x.project_id
  service            = "modelarmor.googleapis.com"
  disable_on_destroy = false
  depends_on         = [time_sleep.wait_for_billing]
}

resource "google_project_service" "aiplatform_api" {
  project            = google_project.model_armor_c0d3x.project_id
  service            = "aiplatform.googleapis.com"
  disable_on_destroy = false
  depends_on         = [time_sleep.wait_for_billing]
}

# =============================================================================
# Floor Setting
# Applies project-wide to all Vertex AI calls via AI_PLATFORM integration.
# pi_and_jailbreak, malicious_uri, and sdp are intentionally DISABLED at
# floor level — these are tested exclusively via template-level enforcement
# to isolate control behaviour per confidence tier.
# =============================================================================

resource "google_model_armor_floorsetting" "project_floor" {
  parent                           = "projects/${google_project.model_armor_c0d3x.project_id}"
  location                         = "global"
  integrated_services              = ["AI_PLATFORM"]
  enable_floor_setting_enforcement = true

  depends_on = [
    google_project_service.modelarmor_api,
    google_billing_project_info.project_billing,
    time_sleep.wait_for_billing,
  ]

  filter_config {
    malicious_uri_filter_settings {
      filter_enforcement = "DISABLED"
    }
    pi_and_jailbreak_filter_settings {
      filter_enforcement = "DISABLED"
    }
    sdp_settings {
      basic_config {
        filter_enforcement = "DISABLED"
      }
    }
    rai_settings {
      rai_filters {
        filter_type = "SEXUALLY_EXPLICIT"
      }
      rai_filters {
        filter_type = "HATE_SPEECH"
      }
      rai_filters {
        filter_type = "HARASSMENT"
      }
      rai_filters {
        filter_type = "DANGEROUS"
      }
    }
  }


  ai_platform_floor_setting {
    inspect_and_block    = true
    enable_cloud_logging = true
  }
}

# =============================================================================
# Local: shared template metadata defaults
# =============================================================================

locals {
  default_metadata = {
    log_template_operations         = true
    log_sanitize_operations         = true
    enable_multi_language_detection = false
    enforcement_type                = "INSPECT_AND_BLOCK"
  }
}

# =============================================================================
# Template 1: Low Confidence (your original)
# Catches the broadest surface — flags anything with even weak signal.
# Expected: high true-positive rate, elevated false-positive rate.
# Test focus: sensitivity floor, obfuscated payload detection.
# =============================================================================

resource "google_model_armor_template" "confidence_low" {
  location    = var.region
  template_id = "confidence-level-low"
  project     = google_project.model_armor_c0d3x.project_id

  labels = {
    environment = "redteam"
    tier        = "low-confidence"
  }

  filter_config {
    malicious_uri_filter_settings {
      filter_enforcement = "ENABLED"
    }
    pi_and_jailbreak_filter_settings {
      filter_enforcement = "ENABLED"
      confidence_level   = "LOW_AND_ABOVE"
    }
    rai_settings {
      rai_filters {
        filter_type      = "DANGEROUS"
        confidence_level = "LOW_AND_ABOVE"
      }
      rai_filters {
        filter_type      = "SEXUALLY_EXPLICIT"
        confidence_level = "LOW_AND_ABOVE"
      }
      rai_filters {
        filter_type      = "HATE_SPEECH"
        confidence_level = "LOW_AND_ABOVE"
      }
      rai_filters {
        filter_type      = "HARASSMENT"
        confidence_level = "LOW_AND_ABOVE"
      }
    }
    sdp_settings {
      basic_config {
        filter_enforcement = "ENABLED"
      }
    }
  }

  template_metadata {
    log_template_operations = local.default_metadata.log_template_operations
    log_sanitize_operations = local.default_metadata.log_sanitize_operations
    multi_language_detection {
      enable_multi_language_detection = local.default_metadata.enable_multi_language_detection
    }
    enforcement_type = local.default_metadata.enforcement_type
  }

  depends_on = [google_project_service.modelarmor_api]
}

# =============================================================================
# Template 2: Medium Confidence
# Production-representative baseline — balanced threshold.
# Expected: catches explicit attacks, may miss obfuscated variants.
# Test focus: benchmarking real-world deployment posture.
# =============================================================================

resource "google_model_armor_template" "confidence_medium" {
  location    = var.region
  template_id = "confidence-level-medium"
  project     = google_project.model_armor_c0d3x.project_id

  labels = {
    environment = "redteam"
    tier        = "medium-confidence"
  }

  filter_config {
    malicious_uri_filter_settings {
      filter_enforcement = "ENABLED"
    }
    pi_and_jailbreak_filter_settings {
      filter_enforcement = "ENABLED"
      confidence_level   = "MEDIUM_AND_ABOVE"
    }
    rai_settings {
      rai_filters {
        filter_type      = "DANGEROUS"
        confidence_level = "MEDIUM_AND_ABOVE"
      }
      rai_filters {
        filter_type      = "SEXUALLY_EXPLICIT"
        confidence_level = "MEDIUM_AND_ABOVE"
      }
      rai_filters {
        filter_type      = "HATE_SPEECH"
        confidence_level = "MEDIUM_AND_ABOVE"
      }
      rai_filters {
        filter_type      = "HARASSMENT"
        confidence_level = "MEDIUM_AND_ABOVE"
      }
    }
    sdp_settings {
      basic_config {
        filter_enforcement = "ENABLED"
      }
    }
  }

  template_metadata {
    log_template_operations = local.default_metadata.log_template_operations
    log_sanitize_operations = local.default_metadata.log_sanitize_operations
    multi_language_detection {
      enable_multi_language_detection = local.default_metadata.enable_multi_language_detection
    }
    enforcement_type = local.default_metadata.enforcement_type
  }

  depends_on = [google_project_service.modelarmor_api]
}

# =============================================================================
# Template 3: High Confidence
# Strictest threshold — blocks only high-certainty matches.
# Expected: lowest false-positive rate, highest bypass risk.
# Test focus: whether sophisticated payloads evade strict filters.
# =============================================================================

resource "google_model_armor_template" "confidence_high" {
  location    = var.region
  template_id = "confidence-level-high"
  project     = google_project.model_armor_c0d3x.project_id

  labels = {
    environment = "redteam"
    tier        = "high-confidence"
  }

  filter_config {
    malicious_uri_filter_settings {
      filter_enforcement = "ENABLED"
    }
    pi_and_jailbreak_filter_settings {
      filter_enforcement = "ENABLED"
      confidence_level   = "HIGH"
    }
    rai_settings {
      rai_filters {
        filter_type      = "DANGEROUS"
        confidence_level = "HIGH"
      }
      rai_filters {
        filter_type      = "SEXUALLY_EXPLICIT"
        confidence_level = "HIGH"
      }
      rai_filters {
        filter_type      = "HATE_SPEECH"
        confidence_level = "HIGH"
      }
      rai_filters {
        filter_type      = "HARASSMENT"
        confidence_level = "HIGH"
      }
    }
    sdp_settings {
      basic_config {
        filter_enforcement = "ENABLED"
      }
    }
  }

  template_metadata {
    log_template_operations = local.default_metadata.log_template_operations
    log_sanitize_operations = local.default_metadata.log_sanitize_operations
    multi_language_detection {
      enable_multi_language_detection = local.default_metadata.enable_multi_language_detection
    }
    enforcement_type = local.default_metadata.enforcement_type
  }

  depends_on = [google_project_service.modelarmor_api]
}

# =============================================================================
# Template 4: Multi-Language Detection
# Medium confidence + multi-language scanning enabled.
# Expected: catches unicode smuggling, l33tspeak, and language-switching
# evasion techniques that the standard templates miss.
# Test focus: obfuscated payload variants across non-English inputs.
# =============================================================================

resource "google_model_armor_template" "multi_language" {
  location    = var.region
  template_id = "confidence-multi-language"
  project     = google_project.model_armor_c0d3x.project_id

  labels = {
    environment = "redteam"
    tier        = "multi-language"
  }

  filter_config {
    malicious_uri_filter_settings {
      filter_enforcement = "ENABLED"
    }
    pi_and_jailbreak_filter_settings {
      filter_enforcement = "ENABLED"
      confidence_level   = "MEDIUM_AND_ABOVE"
    }
    rai_settings {
      rai_filters {
        filter_type      = "DANGEROUS"
        confidence_level = "MEDIUM_AND_ABOVE"
      }
      rai_filters {
        filter_type      = "SEXUALLY_EXPLICIT"
        confidence_level = "MEDIUM_AND_ABOVE"
      }
      rai_filters {
        filter_type      = "HATE_SPEECH"
        confidence_level = "MEDIUM_AND_ABOVE"
      }
      rai_filters {
        filter_type      = "HARASSMENT"
        confidence_level = "MEDIUM_AND_ABOVE"
      }
    }
    sdp_settings {
      basic_config {
        filter_enforcement = "ENABLED"
      }
    }
  }

  template_metadata {
    log_template_operations = local.default_metadata.log_template_operations
    log_sanitize_operations = local.default_metadata.log_sanitize_operations
    multi_language_detection {
      enable_multi_language_detection = true
    }
    enforcement_type = local.default_metadata.enforcement_type
  }

  depends_on = [google_project_service.modelarmor_api]
}

# =============================================================================
# Template 5: Inspect Only — Shadow Mode
# All filters at medium confidence — observe without blocking.
# Expected: logs every filter match with zero impact on availability.
# Test focus: baselining what a production deployment would block before
# committing to enforcement — safe for pre-production pipeline integration.
# =============================================================================

resource "google_model_armor_template" "inspect_only" {
  location    = var.region
  template_id = "confidence-inspect-only"
  project     = google_project.model_armor_c0d3x.project_id

  labels = {
    environment = "redteam"
    tier        = "inspect-only"
  }

  filter_config {
    malicious_uri_filter_settings {
      filter_enforcement = "ENABLED"
    }
    pi_and_jailbreak_filter_settings {
      filter_enforcement = "ENABLED"
      confidence_level   = "MEDIUM_AND_ABOVE"
    }
    rai_settings {
      rai_filters {
        filter_type      = "DANGEROUS"
        confidence_level = "MEDIUM_AND_ABOVE"
      }
      rai_filters {
        filter_type      = "SEXUALLY_EXPLICIT"
        confidence_level = "MEDIUM_AND_ABOVE"
      }
      rai_filters {
        filter_type      = "HATE_SPEECH"
        confidence_level = "MEDIUM_AND_ABOVE"
      }
      rai_filters {
        filter_type      = "HARASSMENT"
        confidence_level = "MEDIUM_AND_ABOVE"
      }
    }
    sdp_settings {
      basic_config {
        filter_enforcement = "ENABLED"
      }
    }
  }

  template_metadata {
    log_template_operations = local.default_metadata.log_template_operations
    log_sanitize_operations = local.default_metadata.log_sanitize_operations
    multi_language_detection {
      enable_multi_language_detection = local.default_metadata.enable_multi_language_detection
    }
    enforcement_type = "INSPECT_ONLY"
  }

  depends_on = [google_project_service.modelarmor_api]
}

# =============================================================================
# Outputs — expose IDs for use by C0D3X agent and payload runner
# =============================================================================

output "project_id" {
  description = "Deployed GCP project ID"
  value       = google_project.model_armor_c0d3x.project_id
}

output "template_ids" {
  description = "All deployed Model Armor template IDs for C0D3X test runs"
  value = {
    low            = google_model_armor_template.confidence_low.template_id
    medium         = google_model_armor_template.confidence_medium.template_id
    high           = google_model_armor_template.confidence_high.template_id
    multi_language = google_model_armor_template.multi_language.template_id
    inspect_only   = google_model_armor_template.inspect_only.template_id
  }
}
