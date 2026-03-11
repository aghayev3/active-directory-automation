# Active Directory Automation & Security Toolset

A professional PowerShell-based framework designed for the automated generation and deployment of complex Active Directory environments. Built with a focus on **Infrastructure as Code (IaC)** and **Cybersecurity Best Practices**.

## 🚀 Overview
This toolset consists of two primary scripts:
1. **`Generate-ADConfig.ps1`**: Generates a stateless JSON configuration representing a full enterprise structure (OUs, Groups, Users, and GPOs).
2. **`Deploy-ADEnvironment.ps1`**: An idempotent deployment script that reads the JSON and builds the environment in Active Directory.

## 🛡️ Security Features
Designed for a defensive security posture, this toolset implements:
* **Secure Identity Management**: Uses a random password generator for new accounts rather than hardcoded defaults.
* **Tiered Administration**: Automatically generates "a-" prefixed administrative accounts for IT staff to demonstrate separation of privileges.
* **Audit Trail**: Every deployment session is automatically logged via PowerShell Transcription for SOC/Auditing purposes.
* **Security Baselines**: Includes pre-configured GPO links for baseline workstation security and strong password policies.

## 🛠️ Usage
1. Run the generator to create your environment model:
   `.\Generate-ADConfig.ps1`
2. Run the deployment script (Dry Run mode by default):
   `.\Deploy-ADEnvironment.ps1`
3. Apply the changes to a live DC:
   `.\Deploy-ADEnvironment.ps1 -Apply`
