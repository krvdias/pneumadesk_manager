# PnumaDesk Manager (v1.0.0)

**PnumaDesk Manager** is a Windows desktop management console engineered for centralized multi-project orchestration, database administration, dynamic client application feature gating, and comprehensive system backups across both Development and Live Production Supabase environments.

Developed and maintained by **Krv Softwares**.

---

## 🌟 Key Capabilities & Features

### 1. Multi-Project & Multi-Database Orchestration
- **Centralized Project Management**: Create, view, edit, and safely delete projects from a single workspace.
- **Dynamic Database Connections**: Link multiple database instances (Dev, Staging, Live) under each project.
- **Config Import via `.env` / `.txt`**: One-click import parser that automatically populates database connection parameters (`SUPABASE_URL`, `SERVICE_ROLE_KEY`, `ANON_KEY`, `DB_HOST`, `DB_PASSWORD`, SMS gateway tokens, and Cloudflare R2 bucket credentials).
- **One-Click Re-Connect & Disconnect**: Real-time client connection verification with status indicators and clean disconnect mechanics.
- **Secured UI**: Database endpoints, host poolers, and database ports remain hidden on the UI to prevent credential exposure.

### 2. Connected Client App Controls (`Church_Mgmt_App` Schema)
- Directly inspects and toggles system applications from connected client databases (`system_apps` table):
  - **Global App Toggle**: Instantly activate or deactivate entire client application modules (e.g., `User App`, `Offering Receipt App`, `Messaging App`).
  - **Granular Role-Based Maintenance Mode**: Dynamically switch maintenance mode on/off per role (`super_admin`, `admin`, `group_leader`).

### 3. Role-Based Access Control (RBAC) & User Management
- **Role Tiering**: Support for `super_admin`, `admin`, and `unknown` (pending) accounts.
  - **First-Account Auto-Bootstrap**: The initial registered account automatically acquires `super_admin` privileges. Subsequent sign-ups are flagged as `unknown` pending approval.
  - **Administrative Super-Rights**: Super Admins can safely delete user accounts via a 2-step confirmation dialog; standard Admins cannot delete user accounts.
  - **Administrative Controls**: Admins and Super Admins can promote/demote roles, reset user passwords, and manage pending registrations.
  - **Logout Confirmation**: Prevents accidental session termination with an explicit confirmation dialog.

### 4. Zero-Friction Database Setup & Recovery
- **Decoupled Database Config Modal**: Accessible via the gear icon (⚙️) on the top-right of the login window.
- **Automatic Schema Initialization & Verification**: Runs SQL table schemas and establishes Row-Level Security (RLS) system policies for all 5 core tables (`users`, `projects`, `project_databases`, `notifications`, `activity_logs`).
- **Target Environment Synchronization**: Automatically updates and points active authentication to Development or Live Production upon configuration.

### 5. Full System Backup & Restore
- **Comprehensive Backups**: Exports complete system state into portable JSON format:
  - System Users & Passwords (securely hashed)
  - Registered Projects
  - Project Databases & linked configuration tokens
  - Audit Trail Activity Logs
  - System Notifications
- **Two-Way Restore Engine**: Restore backups either before login (via the Database Configuration dialog) or from within the user profile view.

### 6. Notifications & Audit Logs
- **System Activity Log**: Real-time audit trails capturing user creations, role alterations, project additions, database connections, and full system backups.
- **Role-Targeted Notifications**: Filterable notification feed supporting role-specific and user-specific broadcasts with read/unread tracking.

### 7. Static Pages & Company Information
- Dedicated modal dialogs accessible from both login and dashboard footers:
  - **Privacy Policy**
  - **Terms & Conditions**
  - **Contact Us**

---

## 🏢 Contact & Maintainer Information

- **Company / Maintainer**: **Krv Softwares**
- **Official Email**: `vishan.dias.official@gmail.com`
- **Hotline**: `+94 78 376 4730`
- **Application Version**: `v1.0.0 (Production Release)`

---

## 🛠️ Technology Stack & Dependencies

- **Framework**: Flutter Desktop (Windows x64)
- **Language**: Dart
- **Backend / Database**: Supabase (PostgreSQL 15+ with pgpooler support)
- **Key Packages**:
  - `supabase_flutter`: Real-time API & PostgREST client
  - `postgres`: Simple query protocol execution for automated schema configuration
  - `provider`: State management
  - `flutter_dotenv`: Dynamic environment management
  - `file_picker`: File selection for configs and backups
  - `crypto`: SHA-256 secure password hashing

---

## 📦 Building the Installer

The production Windows installer is generated using **Inno Setup**:

1. **Build Flutter Release Binary**:
   ```bash
   flutter build windows --release
   ```

2. **Compile the Installer with Inno Setup**:
   ```cmd
   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer.iss
   ```

The compiled installer will be outputted to:
```
installer/PnumaDesk_Manager_Setup_v1.0.0.exe
```

> **Automatic Prerequisites Installation**: The generated installer automatically detects if the Microsoft Visual C++ 2015–2022 Redistributable (x64) runtime is installed on the target machine. If missing, it will automatically install it silently before launching PnumaDesk Manager.

---

## 📄 License
Copyright © 2026 Krv Softwares. All rights reserved.
