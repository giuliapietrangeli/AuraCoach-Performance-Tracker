# AuraCoach 📱⌚💻 

> **A real-time biometric telemetry and AI-driven behavioral analysis suite for public speaking.**

AuraCoach is a multiplatform ecosystem designed to help speakers monitor and manage performance anxiety through real-time physiological analysis and AI-driven post-session feedback.

[![See the video here:](https://drive.google.com/file/d/1dSNWohtnYkWANE2ko5WzAeP70hgD2N-C/view?usp=sharing)](https://drive.google.com/file/d/1dSNWohtnYkWANE2ko5WzAeP70hgD2N-C/view?usp=sharing)

## 🌟 Project Vision
The project was born to address the "Metacognitive Blind Spot": the inability of speakers to objectively perceive their state of agitation and speaking pace during a speech. AuraCoach transforms invisible biometric data into actionable feedback using the concept of **Calm Technology**.

## 📚 Scientific Foundation & Literature Validation
The design choices behind AuraCoach are deeply rooted in cognitive psychology and Human-Computer Interaction (HCI) research. To ensure the system is both effective and non-intrusive, we grounded our architecture in three key scientific studies:

* **The Problem (Cognitive Overload):** We referenced Eysenck et al.'s *Attentional Control Theory* to understand how anxiety consumes working memory. This cognitive overload explains why speakers experience a "blind spot," losing awareness of peripheral cues like their speaking rate or excessive gesticulation during a presentation.
* **The Interaction (Haptic Feedback):** To preserve the speaker's eye contact with the audience, AuraCoach relies on discrete wrist vibrations rather than visual alerts. This interaction model is validated by research on haptic notification systems, which demonstrates the superiority of tactile feedback for timing and pacing awareness during oral presentations.
* **The Efficacy (Biofeedback):** The core intervention of our ecosystem is supported by studies on biofeedback awareness. Research shows that making users aware of their physiological parameters (such as heart rate and agitation) actively helps them manage and lower their physiological stress response in real-time.
* **Interoceptive Anchoring (Entrainment):** Based on studies regarding wearable devices during public speaking anticipation (e.g., Azevedo et al.), we implemented a tactile heartbeat simulation. Providing a slow, rhythmic haptic pulse (simulating a 60 BPM heart rate) induces physiological *entrainment*, subconsciously guiding the speaker's actual heart rate to slow down and sync with the wearable, drastically reducing anxiety without requiring visual attention.

---

## 🚀 Key Features

### ⌚ Biometric Monitoring & Biofeedback (Apple Watch)
* **Real-Time Analysis:** Continuous tracking of heart rate (BPM) and physical agitation via accelerometer (G-force).
* **Silent Haptic Feedback:** Discreet wrist vibrations that act as an "anchor" to regulate breathing without interrupting eye contact with the audience.
* **Tactile Grounding (Digital Crown):** The Apple Watch's Digital Crown acts as an invisible "fidget" tool. Rotating it provides crisp, mechanical haptic clicks, allowing the speaker to discharge nervous energy continuously and discreetly while keeping their hands behind their back or by their sides.
* **Interoceptive Reset (Calm Mode):** A 1.5-second long-press on the watch face activates a 60-second "Calm Mode" (muting all stress alerts) and delivers three deep, slow haptic pulses. This simulates a resting heartbeat, triggering physical calming through rhythmic entrainment and giving the speaker a moment to regain focus.

### 📱 iOS Dashboard & Voice Analysis
* **WPM (Words Per Minute) Analysis:** Speech pace monitoring to identify speed peaks caused by stress.
* **Anxiety Indicator:** A proprietary algorithm cross-references physiological data to display a dynamic real-time anxiety level.
* **Cloud Sync:** Automatic session saving on Firebase for historical consultation and cross-device availability.

### 💻 Mac Dashboard & AI Reporting
* **Clinical AI Analysis:** Uses the **LLaMA-3.3-70b** model (via Groq API) to generate detailed, behavioral reports based on the session's biometric timeline.
* **Asynchronous Review:** A dedicated macOS dashboard for post-event analysis of the collected data.

---

## 🛠️ Tech Stack
* **Language:** Swift / SwiftUI
* **Backend:** Firebase Firestore (Cloud Synchronization) 
* **AI Engine:** Groq API (LLaMA-3.3-70b-versatile)
* **Frameworks:** HealthKit (Biometrics), CoreMotion (Kinematics), Speech (Transcription), WatchConnectivity (Cross-device communication)

---

## 🧠 Human-Computer Interaction (HCI) Process

The design of AuraCoach was strictly driven by a **User-Centered Design** approach.

### 1. Needfinding & Interviews
Through 10 structured interviews, it emerged that:
* Users suffer from a cognitive "blind spot" during high-stakes speeches.
* Visual feedback (e.g., looking at a screen or timer) is considered a source of distraction and additional anxiety.
* Users have a strong desire to analyze their emotional triggers "with a clear head" using objective data.

### 2. Personas
We identified two main archetypes to define our core features:
* **Marzia (The Blind-Spot Sufferer):** Needs invisible haptic feedback to manage speech acceleration during remote video interviews.
* **Marco (The Executive):** Uses the Mac Dashboard to analyze post-session data and improve his physical presence in boardroom meetings where phones/watches cannot be actively checked.

### 3. Prototyping
The design evolved from low-fidelity wireframes to an interactive prototype on Figma, specifically tested to reduce cognitive load during the actual performance.

---

## 📂 Repository Structure

The repository is organized to separate the source code from the HCI research materials:

```text
├── AuraCoach/                  # Main Xcode Workspace
│   ├── AuraCoach/              # iOS App (Logic, UI, Voice Analysis)
│   ├── AuraCoachMac/           # macOS Dashboard (AI Reporting)
│   ├── AuraCoachWatch App/     # watchOS App (Sensors, Haptics)
│   ├── SharedModels.swift      # Cross-platform data models
│   └── AuraCoach.xcodeproj     # Project Configuration
├── HCI Process/                # Design Documentation
│   ├── Needfinding/            # Interviews, Survey, Personas, Storyboards
│   └── Prototypes/             # Screenshots, Figma Interactive Prototype Link, Prototype Feedbacks
├── .gitignore                  # Excludes Xcode temp/user files
└── README.md                   # Project documentation
```

## 🔧 Setup & Installation
1. Clone the repository to your local machine.
2. Ensure you are running Xcode 15 or later.
3. **API Key:** Insert your personal Groq API key inside `AIManager.swift`.
4. Configure your Firebase project and add the `GoogleService-Info.plist` to the corresponding iOS and Mac targets.

---
*Project developed by Giulia Pietrangeli & Lorenzo Musso*
