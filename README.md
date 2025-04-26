# ALPR 2 MQTT

A lightweight and resilient **automatic license plate recognition (ALPR) image monitor**, optimized for high-throughput environments and containerized deployment.

This service continuously watches a directory for new JPEG images, processes each through **openalpr**, and publishes results to an MQTT topic. If plates are not initially detected, a set of smart image transformations is applied to improve success rates.

---

## Features

- Watches a directory (`WATCH_DIR`) for incoming `.jpg` / `.jpeg` files.
- Runs **openalpr** to detect license plates.
- If no plate is found, applies transformations such as **zoom**, **invert**, **grayscale**, **threshold**, **sharpen**, and **contrast stretch**.
- Publishes results as **compact JSON** messages to an MQTT topic.
- Moves unsuccessful detections to a trouble directory (`TROUBLE_DIR`).
- Automatically deletes old files from the trouble directory based on configurable max age (`TROUBLE_MAX_AGE`).
- **Parallel** processing: multiple images and transformations are handled simultaneously.
- Core dump collection ready for debugging crashes.
- Clean, timestamped logging.
- Distributed as a **Docker image** via Docker Hub (upcoming).

---

## Environment Variables

| Variable | Default | Description |
|:---------|:--------|:------------|
| `WATCH_DIR` | `/input` | Directory to monitor for new images |
| `TROUBLE_DIR` | `/trouble` | Directory for images where no plate was detected |
| `TROUBLE_MAX_AGE` | `86400` | Max age (in seconds) for trouble images before deletion |
| `MQTT_HOST` | `localhost` | MQTT broker hostname |
| `MQTT_PORT` | `1883` | MQTT broker port |
| `MQTT_TOPIC` | `your/topic` | MQTT topic to publish results |
| `MQTT_USERNAME` | *(optional)* | MQTT username for authentication |
| `MQTT_PASSWORD` | *(optional)* | MQTT password for authentication |
| `MQTT_CLIENT_ID` | *(optional)* | MQTT client identifier |

---

## Usage

Run the service using Docker Compose:

```yaml
services:
  alpr-monitor:
    image: your-dockerhub-username/alpr-monitor:latest
    container_name: alpr-monitor
    environment:
      - WATCH_DIR=/input
      - TROUBLE_DIR=/trouble
      - TROUBLE_MAX_AGE=86400
      - MQTT_HOST=your.mqtt.host
      - MQTT_PORT=1883
      - MQTT_TOPIC=alpr/results
      - MQTT_USERNAME=youruser
      - MQTT_PASSWORD=yourpass
    volumes:
      - ./input:/input
      - ./trouble:/trouble
    privileged: true
    restart: unless-stopped
```

---

## Building and Publishing the Docker Image

To build:

```bash
docker build -t your-dockerhub-username/alpr-monitor .
```

To push to Docker Hub:

```bash
docker push your-dockerhub-username/alpr-monitor
```

---

## Example Output

**On successful plate detection:**

```json
{
  "version": 2,
  "data_type": "alpr_results",
  "epoch_time": 1745680884624,
  "img_width": 640,
  "img_height": 480,
  "processing_time_ms": 95.2,
  "regions_of_interest": [...],
  "results": [...],
  "transform_used": "grayscale"
}
```

**If no plate was detected:**

```json
{
  "error": "no_plate_found",
  "file": "example.jpg"
}
```

---

## Notes

- Requires `convert` (ImageMagick) and `openalpr` binaries installed inside the container.
- Core dumps are collected under `/cores/` inside the container when crashes occur.
- Parallelization is tuned for environments where multiple images may be dropped simultaneously.
- Logging is fully timestamped for easy debugging.

---

## License

Distributed under the MIT License.

---
