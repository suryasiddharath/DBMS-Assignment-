"""Veterinary Clinic and Animal Treatment Management System - Streamlit front-end.

Run:   pip install streamlit mysql-connector-python pandas
       streamlit run app.py
Set your MySQL password first (see DB_PASSWORD below) and run vet_clinic.sql once.
"""
import os
import re
from datetime import date, datetime, time

import mysql.connector
import pandas as pd
import streamlit as st

DB = dict(
    host=os.getenv("DB_HOST", "localhost"),
    user=os.getenv("DB_USER", "root"),
    password=os.getenv("DB_PASSWORD", ""),   # <- put your MySQL password here or set DB_PASSWORD
    database=os.getenv("DB_NAME", "vet_clinic"),
)

st.set_page_config(page_title="Vet Clinic DBMS", layout="wide")


# ---------------------------------------------------------------- helpers
def conn():
    return mysql.connector.connect(**DB)


def query(sql, params=None):
    """Run a SELECT and return a DataFrame. Errors are shown, never crash the app."""
    try:
        c = conn()
        try:
            cur = c.cursor(dictionary=True)
            cur.execute(sql, params or ())
            return pd.DataFrame(cur.fetchall())
        finally:
            c.close()
    except mysql.connector.Error as e:
        st.error(f"Database error: {e.msg}")
        return pd.DataFrame()


def execute(sql, params=None, ok="Saved successfully."):
    """Run INSERT/UPDATE/DELETE. Trigger and constraint messages are shown to the user."""
    try:
        c = conn()
        try:
            cur = c.cursor()
            cur.execute(sql, params or ())
            c.commit()
            st.success(ok)
            return True
        except mysql.connector.Error:
            c.rollback()
            raise
        finally:
            c.close()
    except mysql.connector.Error as e:
        st.error(f"Could not save: {e.msg}")
        return False


def options(sql, params=None):
    """First column = id, second column = label. Returns {id: label}."""
    df = query(sql, params)
    if df.empty:
        return {}
    idc, lab = df.columns[0], df.columns[1]
    return {int(r[idc]): str(r[lab]) for _, r in df.iterrows()}


def pick(label, opts, key=None):
    if not opts:
        st.info(f"No records available for: {label}")
        return None
    return st.selectbox(label, list(opts.keys()), format_func=lambda k: opts[k], key=key)


def show(df):
    if df.empty:
        st.caption("No records found.")
    else:
        st.dataframe(df, width="stretch", hide_index=True)


def valid_phone(p):
    return bool(re.fullmatch(r"[0-9]{10,15}", p or ""))


def valid_email(e):
    return (not e) or bool(re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", e))


# ---------------------------------------------------------------- pages
def page_dashboard():
    st.header("Dashboard")
    df = query("""SELECT
        (SELECT COUNT(*) FROM owner) AS owners,
        (SELECT COUNT(*) FROM animal) AS animals,
        (SELECT COUNT(*) FROM appointment WHERE status='Scheduled') AS upcoming_appointments,
        (SELECT COALESCE(SUM(amount),0) FROM payment) AS revenue""")
    if not df.empty:
        r = df.iloc[0]
        c1, c2, c3, c4 = st.columns(4)
        c1.metric("Owners", int(r["owners"]))
        c2.metric("Animals", int(r["animals"]))
        c3.metric("Upcoming appointments", int(r["upcoming_appointments"]))
        c4.metric("Revenue collected", f"Rs {float(r['revenue']):,.2f}")
    st.subheader("Upcoming appointments")
    show(query("SELECT * FROM v_doctor_schedule WHERE status='Scheduled' ORDER BY appt_start"))


def page_owners():
    st.header("Owners")
    t_view, t_add, t_upd, t_del = st.tabs(["View / search", "Add", "Update", "Delete"])

    with t_view:
        term = st.text_input("Search by name or phone", key="own_search")
        like = f"%{term}%"
        show(query("""SELECT owner_id, full_name, phone, email, address FROM owner
                      WHERE full_name LIKE %s OR phone LIKE %s ORDER BY full_name""", (like, like)))

    with t_add:
        with st.form("add_owner", clear_on_submit=True):
            name = st.text_input("Full name")
            phone = st.text_input("Phone (10-15 digits)")
            email = st.text_input("Email (optional)")
            addr = st.text_input("Address")
            if st.form_submit_button("Add owner"):
                if not name.strip():
                    st.error("Name is required.")
                elif not valid_phone(phone):
                    st.error("Phone must be 10 to 15 digits.")
                elif not valid_email(email):
                    st.error("Email format is invalid.")
                else:
                    execute("INSERT INTO owner (full_name, phone, email, address) VALUES (%s,%s,%s,%s)",
                            (name.strip(), phone, email or None, addr or None), "Owner added.")

    with t_upd:
        oid = pick("Select owner", options("SELECT owner_id, full_name FROM owner ORDER BY full_name"), "upd_own")
        if oid:
            cur = query("SELECT * FROM owner WHERE owner_id=%s", (oid,)).iloc[0]
            with st.form("upd_owner"):
                name = st.text_input("Full name", cur["full_name"])
                phone = st.text_input("Phone", cur["phone"])
                email = st.text_input("Email", cur["email"] or "")
                addr = st.text_input("Address", cur["address"] or "")
                if st.form_submit_button("Update owner"):
                    if not name.strip() or not valid_phone(phone) or not valid_email(email):
                        st.error("Check name, phone (10-15 digits) and email format.")
                    else:
                        execute("""UPDATE owner SET full_name=%s, phone=%s, email=%s, address=%s
                                   WHERE owner_id=%s""", (name.strip(), phone, email or None, addr or None, oid),
                                "Owner updated.")

    with t_del:
        oid = pick("Select owner to delete", options("SELECT owner_id, full_name FROM owner ORDER BY full_name"), "del_own")
        if oid:
            st.warning("An owner who still has animals cannot be deleted.")
            if st.checkbox("I confirm the deletion", key="del_own_ok") and st.button("Delete owner"):
                execute("DELETE FROM owner WHERE owner_id=%s", (oid,), "Owner deleted.")


def page_animals():
    st.header("Animals")
    t_view, t_add, t_upd, t_del = st.tabs(["View / search", "Register animal", "Update", "Delete"])

    with t_view:
        term = st.text_input("Search by animal or owner name", key="an_search")
        like = f"%{term}%"
        show(query("""SELECT a.animal_id, a.name, o.full_name AS owner, s.species_name AS species,
                             b.breed_name AS breed, a.gender, a.date_of_birth, a.weight_kg
                      FROM animal a JOIN owner o ON o.owner_id=a.owner_id
                      JOIN breed b ON b.breed_id=a.breed_id JOIN species s ON s.species_id=b.species_id
                      WHERE a.name LIKE %s OR o.full_name LIKE %s ORDER BY a.name""", (like, like)))

    with t_add:
        owners = options("SELECT owner_id, full_name FROM owner ORDER BY full_name")
        breeds = options("""SELECT b.breed_id, CONCAT(s.species_name,' - ',b.breed_name)
                            FROM breed b JOIN species s ON s.species_id=b.species_id ORDER BY 2""")
        with st.form("add_animal", clear_on_submit=True):
            oid = pick("Owner", owners)
            bid = pick("Breed", breeds)
            name = st.text_input("Animal name")
            gender = st.selectbox("Gender", ["Male", "Female"])
            dob = st.date_input("Date of birth", value=date(2022, 1, 1),
                                min_value=date(1990, 1, 1), max_value=date.today())
            weight = st.number_input("Weight (kg)", min_value=0.01, value=1.0, step=0.1)
            if st.form_submit_button("Register animal"):
                if not (oid and bid):
                    st.error("Owner and breed are required.")
                elif not name.strip():
                    st.error("Animal name is required.")
                else:
                    execute("""INSERT INTO animal (owner_id, breed_id, name, gender, date_of_birth, weight_kg)
                               VALUES (%s,%s,%s,%s,%s,%s)""", (oid, bid, name.strip(), gender, dob, weight),
                            "Animal registered.")

    with t_upd:
        aid = pick("Select animal", options("""SELECT a.animal_id, CONCAT(a.name,' (',o.full_name,')')
                                               FROM animal a JOIN owner o ON o.owner_id=a.owner_id ORDER BY a.name"""), "upd_an")
        if aid:
            cur = query("SELECT * FROM animal WHERE animal_id=%s", (aid,)).iloc[0]
            with st.form("upd_animal"):
                name = st.text_input("Name", cur["name"])
                weight = st.number_input("Weight (kg)", min_value=0.01, value=float(cur["weight_kg"]), step=0.1)
                if st.form_submit_button("Update animal"):
                    if not name.strip():
                        st.error("Name is required.")
                    else:
                        execute("UPDATE animal SET name=%s, weight_kg=%s WHERE animal_id=%s",
                                (name.strip(), weight, aid), "Animal updated.")

    with t_del:
        aid = pick("Select animal to delete", options("""SELECT a.animal_id, CONCAT(a.name,' (',o.full_name,')')
                                                         FROM animal a JOIN owner o ON o.owner_id=a.owner_id ORDER BY a.name"""), "del_an")
        if aid:
            st.warning("An animal with appointments or vaccinations cannot be deleted.")
            if st.checkbox("I confirm the deletion", key="del_an_ok") and st.button("Delete animal"):
                execute("DELETE FROM animal WHERE animal_id=%s", (aid,), "Animal deleted.")


def page_appointments():
    st.header("Appointments")
    t_book, t_view, t_status = st.tabs(["Book", "Schedule", "Update status"])

    with t_book:
        animals = options("""SELECT a.animal_id, CONCAT(a.name,' (',o.full_name,')')
                             FROM animal a JOIN owner o ON o.owner_id=a.owner_id ORDER BY a.name""")
        vets = options("SELECT vet_id, full_name FROM veterinarian WHERE is_active=TRUE ORDER BY full_name")
        with st.form("book_appt", clear_on_submit=True):
            aid = pick("Animal", animals)
            vid = pick("Veterinarian", vets)
            d = st.date_input("Date", min_value=date.today())
            t = st.time_input("Start time", value=time(10, 0))
            mins = st.selectbox("Duration (minutes)", [15, 30, 45, 60], index=1)
            reason = st.text_input("Reason for visit")
            if st.form_submit_button("Book appointment"):
                if not (aid and vid):
                    st.error("Select an animal and a veterinarian.")
                else:
                    start = datetime.combine(d, t)
                    execute("""INSERT INTO appointment (animal_id, vet_id, appt_start, appt_end, reason)
                               VALUES (%s,%s,%s, DATE_ADD(%s, INTERVAL %s MINUTE), %s)""",
                            (aid, vid, start, start, mins, reason or None), "Appointment booked.")

    with t_view:
        vets = {0: "All veterinarians"}
        vets.update(options("SELECT vet_id, full_name FROM veterinarian ORDER BY full_name"))
        vid = st.selectbox("Filter by veterinarian", list(vets.keys()), format_func=lambda k: vets[k])
        if vid == 0:
            show(query("SELECT * FROM v_doctor_schedule ORDER BY appt_start"))
        else:
            show(query("SELECT * FROM v_doctor_schedule WHERE vet=%s ORDER BY appt_start", (vets[vid],)))

    with t_status:
        appts = options("""SELECT a.appointment_id,
                                  CONCAT('#',a.appointment_id,' ',an.name,' - ',DATE_FORMAT(a.appt_start,'%d %b %H:%i'),' [',a.status,']')
                           FROM appointment a JOIN animal an ON an.animal_id=a.animal_id
                           ORDER BY a.appt_start DESC""")
        aid = pick("Appointment", appts, "st_appt")
        if aid:
            new = st.selectbox("New status", ["Scheduled", "Completed", "Cancelled"])
            if st.button("Update status"):
                execute("UPDATE appointment SET status=%s WHERE appointment_id=%s", (new, aid), "Status updated.")


def page_consultation():
    st.header("Consultation")
    st.caption("Saves the consultation, diagnosis and treatment together as one transaction.")
    appts = options("""SELECT a.appointment_id,
                              CONCAT('#',a.appointment_id,' ',an.name,' - ',DATE_FORMAT(a.appt_start,'%d %b %H:%i'))
                       FROM appointment a JOIN animal an ON an.animal_id=a.animal_id
                       WHERE a.status<>'Cancelled'
                         AND a.appointment_id NOT IN (SELECT appointment_id FROM consultation)
                       ORDER BY a.appt_start""")
    with st.form("consult", clear_on_submit=True):
        aid = pick("Appointment", appts)
        symptoms = st.text_area("Symptoms")
        notes = st.text_area("Notes")
        diagnosis = st.text_input("Diagnosis")
        treatment = st.text_input("Treatment given")
        cost = st.number_input("Treatment cost (Rs)", min_value=0.0, value=0.0, step=50.0)
        if st.form_submit_button("Save consultation"):
            if not aid:
                st.error("Select an appointment.")
            elif not diagnosis.strip():
                st.error("Diagnosis is required.")
            else:
                try:
                    c = conn()
                    try:
                        cur = c.cursor()
                        cur.execute("INSERT INTO consultation (appointment_id, symptoms, notes) VALUES (%s,%s,%s)",
                                    (aid, symptoms or None, notes or None))
                        cid = cur.lastrowid
                        cur.execute("INSERT INTO diagnosis (consultation_id, description) VALUES (%s,%s)",
                                    (cid, diagnosis.strip()))
                        if treatment.strip():
                            cur.execute("INSERT INTO treatment (consultation_id, description, cost) VALUES (%s,%s,%s)",
                                        (cid, treatment.strip(), cost))
                        cur.execute("UPDATE appointment SET status='Completed' WHERE appointment_id=%s", (aid,))
                        c.commit()
                        st.success(f"Consultation #{cid} saved.")
                    except mysql.connector.Error:
                        c.rollback()
                        raise
                    finally:
                        c.close()
                except mysql.connector.Error as e:
                    st.error(f"Nothing was saved: {e.msg}")
    st.subheader("Recent consultations")
    show(query("SELECT * FROM v_animal_history ORDER BY visit_date DESC LIMIT 20"))


def page_rx_tests():
    st.header("Prescriptions and tests")
    cons = options("""SELECT c.consultation_id,
                             CONCAT('#',c.consultation_id,' ',an.name,' - ',DATE_FORMAT(a.appt_start,'%d %b'))
                      FROM consultation c JOIN appointment a ON a.appointment_id=c.appointment_id
                      JOIN animal an ON an.animal_id=a.animal_id ORDER BY a.appt_start DESC""")
    cid = pick("Consultation", cons, "rx_cons")
    if not cid:
        return
    t_rx, t_test = st.tabs(["Prescription", "Tests"])

    with t_rx:
        meds = options("SELECT medicine_id, name FROM medicine ORDER BY name")
        with st.form("rx", clear_on_submit=True):
            mid = pick("Medicine", meds)
            dose = st.number_input("Dosage (mg)", value=0.0, step=0.5)
            freq = st.text_input("Frequency (e.g. Twice daily)")
            days = st.number_input("Duration (days)", min_value=0, value=5, step=1)
            qty = st.number_input("Quantity (units)", min_value=0, value=1, step=1)
            if st.form_submit_button("Add prescription"):
                if not mid or not freq.strip():
                    st.error("Medicine and frequency are required.")
                elif dose <= 0 or days <= 0 or qty <= 0:
                    st.error("Dosage, duration and quantity must be positive.")
                else:
                    execute("""INSERT INTO prescription (consultation_id, medicine_id, dosage_mg, frequency,
                                                         duration_days, quantity) VALUES (%s,%s,%s,%s,%s,%s)""",
                            (cid, mid, dose, freq.strip(), days, qty), "Prescription added.")
        show(query("""SELECT m.name AS medicine, p.dosage_mg, p.frequency, p.duration_days, p.quantity
                      FROM prescription p JOIN medicine m ON m.medicine_id=p.medicine_id
                      WHERE p.consultation_id=%s""", (cid,)))

    with t_test:
        types = options("SELECT test_type_id, test_name FROM test_type ORDER BY test_name")
        with st.form("test", clear_on_submit=True):
            tid = pick("Test", types)
            tdate = st.date_input("Test date", max_value=date.today())
            status = st.selectbox("Status", ["Pending", "Completed"])
            result = st.text_input("Result")
            if st.form_submit_button("Add test"):
                if not tid:
                    st.error("Select a test.")
                else:
                    execute("""INSERT INTO animal_test (consultation_id, test_type_id, test_date, result, status)
                               VALUES (%s,%s,%s,%s,%s)""", (cid, tid, tdate, result or None, status), "Test recorded.")
        show(query("""SELECT tt.test_name, t.test_date, t.status, t.result
                      FROM animal_test t JOIN test_type tt ON tt.test_type_id=t.test_type_id
                      WHERE t.consultation_id=%s""", (cid,)))
    st.info("After changing prescriptions or tests, regenerate the bill from the Billing page.")


def page_vaccination():
    st.header("Vaccination")
    t_add, t_due = st.tabs(["Record vaccination", "Due soon"])

    with t_add:
        animals = options("""SELECT a.animal_id, CONCAT(a.name,' (',o.full_name,')')
                             FROM animal a JOIN owner o ON o.owner_id=a.owner_id ORDER BY a.name""")
        vaccines = options("SELECT vaccine_id, name FROM vaccine ORDER BY name")
        vets = options("SELECT vet_id, full_name FROM veterinarian WHERE is_active=TRUE ORDER BY full_name")
        with st.form("vacc", clear_on_submit=True):
            aid = pick("Animal", animals)
            vcid = pick("Vaccine", vaccines)
            vid = pick("Veterinarian", vets)
            given = st.date_input("Date given", max_value=date.today())
            st.caption("Next due date is calculated from the vaccine's validity period.")
            if st.form_submit_button("Save vaccination"):
                if not (aid and vcid and vid):
                    st.error("Select animal, vaccine and veterinarian.")
                else:
                    execute("""INSERT INTO vaccination (animal_id, vaccine_id, vet_id, given_date, next_due_date)
                               SELECT %s,%s,%s,%s, DATE_ADD(%s, INTERVAL validity_days DAY)
                               FROM vaccine WHERE vaccine_id=%s""",
                            (aid, vcid, vid, given, given, vcid), "Vaccination recorded.")
        st.subheader("All vaccinations")
        show(query("""SELECT an.name AS animal, vc.name AS vaccine, vx.given_date, vx.next_due_date
                      FROM vaccination vx JOIN animal an ON an.animal_id=vx.animal_id
                      JOIN vaccine vc ON vc.vaccine_id=vx.vaccine_id ORDER BY vx.given_date DESC"""))

    with t_due:
        show(query("SELECT * FROM v_vaccination_due ORDER BY next_due_date"))


def page_billing():
    st.header("Billing and payment")
    t_gen, t_pay, t_out = st.tabs(["Generate bill", "Take payment", "Outstanding"])

    with t_gen:
        cons = options("""SELECT c.consultation_id,
                                 CONCAT('#',c.consultation_id,' ',an.name,' - ',DATE_FORMAT(a.appt_start,'%d %b'))
                          FROM consultation c JOIN appointment a ON a.appointment_id=c.appointment_id
                          JOIN animal an ON an.animal_id=a.animal_id ORDER BY a.appt_start DESC""")
        cid = pick("Consultation", cons, "bill_cons")
        if cid and st.button("Generate / refresh bill"):
            try:
                c = conn()
                try:
                    c.cursor().callproc("generate_bill", (cid,))
                    c.commit()
                    st.success("Bill generated.")
                finally:
                    c.close()
            except mysql.connector.Error as e:
                st.error(f"Could not generate bill: {e.msg}")
        if cid:
            show(query("SELECT bill_id, bill_date, total_amount, status FROM bill WHERE consultation_id=%s", (cid,)))

    with t_pay:
        bills = options("""SELECT bill_id, CONCAT('Bill #',bill_id,' - ',animal,' (',owner,') balance Rs ',balance)
                           FROM v_outstanding_bills ORDER BY bill_id""")
        bid = pick("Bill", bills, "pay_bill")
        if bid:
            bal = float(query("SELECT balance FROM v_outstanding_bills WHERE bill_id=%s", (bid,)).iloc[0]["balance"])
            with st.form("pay", clear_on_submit=True):
                amt = st.number_input("Amount (Rs)", min_value=0.01, value=bal, step=10.0)
                method = st.selectbox("Method", ["Cash", "Card", "UPI"])
                if st.form_submit_button("Record payment"):
                    execute("INSERT INTO payment (bill_id, amount, method) VALUES (%s,%s,%s)",
                            (bid, amt, method), "Payment recorded.")

    with t_out:
        show(query("SELECT * FROM v_outstanding_bills"))


def page_reports():
    st.header("Reports")
    reports = {
        "Animal history": "SELECT * FROM v_animal_history ORDER BY visit_date DESC",
        "Vaccination due (next 30 days)": "SELECT * FROM v_vaccination_due ORDER BY next_due_date",
        "Doctor schedule": "SELECT * FROM v_doctor_schedule ORDER BY vet, appt_start",
        "Prescriptions": "SELECT * FROM v_prescriptions",
        "Tests": "SELECT * FROM v_tests",
        "Outstanding bills": "SELECT * FROM v_outstanding_bills",
        "Revenue by month": "SELECT * FROM v_revenue_by_month",
        "Animals never vaccinated": "SELECT name FROM animal WHERE animal_id NOT IN (SELECT animal_id FROM vaccination)",
    }
    name = st.selectbox("Choose a report", list(reports.keys()))
    df = query(reports[name])
    show(df)
    if not df.empty:
        st.download_button("Download CSV", df.to_csv(index=False), f"{name}.csv", "text/csv")


# ---------------------------------------------------------------- navigation
PAGES = {
    "Dashboard": page_dashboard,
    "Owners": page_owners,
    "Animals": page_animals,
    "Appointments": page_appointments,
    "Consultation": page_consultation,
    "Prescriptions and tests": page_rx_tests,
    "Vaccination": page_vaccination,
    "Billing and payment": page_billing,
    "Reports": page_reports,
}

st.sidebar.title("Vet Clinic")
choice = st.sidebar.radio("Go to", list(PAGES.keys()))

try:
    conn().close()
except mysql.connector.Error as err:
    st.error(f"Cannot connect to MySQL: {err.msg}. Check DB_HOST, DB_USER, DB_PASSWORD and that vet_clinic.sql was run.")
    st.stop()

PAGES[choice]()
