# Tapo NAS — AI Notes

This file records project facts and lessons that AI assistants should not have to reconstruct from conversation history.

## Repository

- GitHub: hunghvt-cyber/tapo-nas-lab
- FnNAS working path: /vol1/Docker/tapo-nas-lab

Detailed implementation and test documentation belongs in the Tapo NAS repository, not here.

## Stable recorder baseline

- Cam1 and Cam2 have stable 24/7 H.264 stream-copy recorders.
- Recording uses 5-minute MP4 segments.
- Recorder services are production/stable work and must not be casually changed while working on event/timeline features.
- Do not replace the lightweight stream-copy design with a heavy NVR/AI-video stack without an explicit architectural decision.

## Motion/event baseline

- ONVIF Notify is the proven production event path.
- PullMessages was investigated as a research path and is not the production event path.
- Cam1 ONVIF lifecycle and motion Notify flow were proven, including subscribe, motion notify, renew, notify after renew, unsubscribe and no notify after unsubscribe.
- Cam2 still requires the corresponding full validation when that phase is resumed.

## Event Logger / timeline direction

- Event Logger phase is complete.
- The intended next direction is event -> existing 5-minute segment marker/selection.
- Do not automatically extract pre/post event clips unless explicitly reintroduced as a new architectural decision.
- The viewer goal is a per-camera/date timeline showing recording coverage and event markers, with controls to select segments for keep/discard/upload.

## Resource constraints

- FnNAS is a lightweight NAS platform with limited CPU/RAM.
- Avoid unnecessary continuous video analysis or heavyweight services.
- A previous vmafmotion experiment was rejected for normal multi-camera use because of excessive CPU cost.
- Recorder stream-copy is intentionally lightweight.

## Lessons for AI assistants

- Do not redesign a stable phase because a theoretically more sophisticated approach exists.
- Do not confuse an investigated/research path with the production path.
- Check the current project handoff/state before proposing implementation.
- Preserve already-proven components unless the task explicitly targets them.
- When the user says "continue", continue from the current phase instead of reopening completed architecture decisions.
