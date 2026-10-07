# DBMS-Course-Project

**Design and Implementation of a Database Management System for Veterinary Clinic and Animal Treatment Management System**

| | |
|---|---|
| **Name** | Surya Siddharath Y |
| **Roll No.** | 25WU0102280 |
| **Class / Section** | AI/ML (Whales) |
| **Project No.** | 47 |

A MySQL database and Streamlit web app that manages owners, animals, appointments, consultations, vaccinations, prescriptions, tests, billing and payments for a veterinary clinic.

## Repository Structure

| Folder | Contents |
|---|---|
| Presentation-I | Problem description slides |
| Presentation-II | Slides, ER diagram, SQL file, Presentation-II query solution |
| Presentation-III | UI demo slides, source code, screenshots |
| Project-Report | Final project report (PDF) |

## How to Run

1. Install MySQL and Python 3.
2. Load the database: `mysql -u root -p < vet_clinic.sql`
3. Install packages: `pip3 install streamlit mysql-connector-python pandas`
4. Set your MySQL password: `export DB_PASSWORD='your_password'`
5. Start the app: `python3 -m streamlit run app.py`

## Technologies

MySQL, Python, Streamlit, mysql-connector-python, pandas
