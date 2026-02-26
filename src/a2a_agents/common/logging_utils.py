# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Logging utilities for Google Cloud integration."""

import logging
import os


def setup_cloud_logging(log_name: str | None = None) -> None:
    """Initializes Google Cloud Logging if running in a remote environment.

    This function sets up the Stackdriver logging handler to integrate with
    the standard Python logging module. It only activates when PROJECT_ID
    is set, which typically indicates a cloud environment.

    Args:
        log_name: Optional name for the cloud log.
    """
    project_id = os.environ.get("PROJECT_ID")
    if not project_id:
        logging.info("PROJECT_ID not set, skipping Cloud Logging setup.")
        return

    try:
        import google.cloud.logging
        from google.cloud.logging.handlers import CloudLoggingHandler

        client = google.cloud.logging.Client(project=project_id)
        # Setup standard Python logging to send logs to Cloud Logging
        handler = CloudLoggingHandler(client, name=log_name)
        
        # Prevent duplicate handlers
        root_logger = logging.getLogger()
        if any(isinstance(h, CloudLoggingHandler) for h in root_logger.handlers):
            logging.info("Cloud Logging handler already exists, skipping.")
            return

        # Add the cloud logging handler to the root logger
        root_logger.addHandler(handler)
        logging.info(f"Cloud Logging initialized for project: {project_id}")

    except Exception as e:
        # Don't let logging initialization fail the whole application
        logging.warning(f"Failed to initialize Cloud Logging: {e}")
