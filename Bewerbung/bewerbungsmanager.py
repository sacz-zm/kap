import sys, os, csv, sqlite3, datetime as dt
from PySide6.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QHBoxLayout, QFormLayout, QLineEdit,
    QDateEdit, QComboBox, QTextEdit, QPushButton, QTableWidget, QTableWidgetItem,
    QFileDialog, QMessageBox, QLabel, QSpinBox
)
from PySide6.QtCore import Qt, QDate

DB_FILE = "bewerbungen.db"
STATUS_OPTS = ["Entwurf", "Gesendet", "Einladung", "Absage", "In Bearbeitung", "Sonstiges"]

def db():
    con = sqlite3.connect(DB_FILE)
    con.execute("""
        CREATE TABLE IF NOT EXISTS apps(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            firma TEXT NOT NULL,
            position TEXT NOT NULL,
            ansprechpartner TEXT,
            datum TEXT NOT NULL,
            status TEXT NOT NULL,
            notizen TEXT
        )
    """)
    return con

def row_to_items(row):
    return [
        QTableWidgetItem(str(row["id"])),
        QTableWidgetItem(row["firma"] or ""),
        QTableWidgetItem(row["position"] or ""),
        QTableWidgetItem(row["ansprechpartner"] or ""),
        QTableWidgetItem(row["datum"] or ""),
        QTableWidgetItem(row["status"] or ""),
        QTableWidgetItem(row["notizen"] or ""),
    ]

def fetch_all(con, filters=None, search=""):
    con.row_factory = sqlite3.Row
    q = "SELECT * FROM apps"
    args = []
    where = []
    if filters and filters.get("status") and filters["status"] != "Alle":
        where.append("status = ?"); args.append(filters["status"])
    if filters and filters.get("firma"):
        where.append("firma LIKE ?"); args.append(f"%{filters['firma']}%")
    if search:
        where.append("(firma LIKE ? OR position LIKE ? OR ansprechpartner LIKE ? OR notizen LIKE ?)")
        args += [f"%{search}%"]*4
    if where: q += " WHERE " + " AND ".join(where)
    q += " ORDER BY date(datum) DESC, id DESC"
    return con.execute(q, args).fetchall()

class App(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Bewerbungsmanager (PySide6)")
        self.con = db()

        # --- Form links
        form = QFormLayout()
        self.in_firma = QLineEdit()
        self.in_position = QLineEdit()
        self.in_anspr = QLineEdit()
        self.in_datum = QDateEdit(calendarPopup=True); self.in_datum.setDate(QDate.currentDate())
        self.in_datum.setDisplayFormat("yyyy-MM-dd")
        self.in_status = QComboBox(); self.in_status.addItems(STATUS_OPTS)
        self.in_notiz = QTextEdit(); self.in_notiz.setFixedHeight(70)

        form.addRow("Firma", self.in_firma)
        form.addRow("Position", self.in_position)
        form.addRow("Ansprechpartner", self.in_anspr)
        form.addRow("Datum", self.in_datum)
        form.addRow("Status", self.in_status)
        form.addRow("Notizen", self.in_notiz)

        btn_add = QPushButton("Neu anlegen")
        btn_save = QPushButton("Speichern (aktuelle Zeile)")
        btn_del = QPushButton("Löschen (aktuelle Zeile)")
        btn_export = QPushButton("Export CSV")
        btn_add.clicked.connect(self.add_record)
        btn_save.clicked.connect(self.save_current)
        btn_del.clicked.connect(self.delete_current)
        btn_export.clicked.connect(self.export_csv)

        left = QVBoxLayout()
        left.addLayout(form)
        left_btns = QHBoxLayout(); left_btns.addWidget(btn_add); left_btns.addWidget(btn_save); left_btns.addWidget(btn_del)
        left.addLayout(left_btns)
        left.addWidget(btn_export)

        # --- Filter/ Suche oben rechts
        top = QHBoxLayout()
        self.f_status = QComboBox(); self.f_status.addItems(["Alle"] + STATUS_OPTS)
        self.f_firma = QLineEdit(); self.f_firma.setPlaceholderText("Filter Firma")
        self.f_search = QLineEdit(); self.f_search.setPlaceholderText("Suche: Firma/Position/Ansprechpartner/Notizen")
        self.f_days = QSpinBox(); self.f_days.setRange(1, 365); self.f_days.setValue(7)
        self.lbl_rem = QLabel("")  # Hinweis Erinnerungen
        btn_refresh = QPushButton("Aktualisieren")
        top.addWidget(QLabel("Status")); top.addWidget(self.f_status)
        top.addWidget(self.f_firma); top.addWidget(self.f_search)
        top.addWidget(QLabel("Erinnerungstage")); top.addWidget(self.f_days)
        top.addWidget(btn_refresh)
        top.addWidget(self.lbl_rem)
        btn_refresh.clicked.connect(self.refresh)

        # --- Tabelle
        self.tbl = QTableWidget(0, 7)
        self.tbl.setHorizontalHeaderLabels(["ID", "Firma", "Position", "Ansprechpartner", "Datum", "Status", "Notizen"])
        self.tbl.setSelectionBehavior(self.tbl.SelectionBehavior.SelectRows)
        self.tbl.setEditTriggers(self.tbl.EditTrigger.NoEditTriggers)
        self.tbl.itemSelectionChanged.connect(self.sync_form_from_selection)
        self.tbl.setSortingEnabled(True)

        # --- Layout gesamt
        main = QHBoxLayout()
        main.addLayout(left, 1)
        right = QVBoxLayout()
        right.addLayout(top)
        right.addWidget(self.tbl, 1)
        main.addLayout(right, 2)
        self.setLayout(main)

        self.refresh()

    def add_record(self):
        firma = self.in_firma.text().strip()
        position = self.in_position.text().strip()
        if not firma or not position:
            QMessageBox.warning(self, "Hinweis", "Firma und Position sind Pflicht.")
            return
        datum = self.in_datum.date().toString("yyyy-MM-dd")
        status = self.in_status.currentText()
        anspr = self.in_anspr.text().strip()
        notizen = self.in_notiz.toPlainText().strip()
        with self.con:
            self.con.execute(
                "INSERT INTO apps(firma,position,ansprechpartner,datum,status,notizen) VALUES(?,?,?,?,?,?)",
                (firma, position, anspr, datum, status, notizen)
            )
        self.clear_form()
        self.refresh()

    def save_current(self):
        row = self.tbl.currentRow()
        if row < 0:
            QMessageBox.information(self, "Hinweis", "Keine Zeile ausgewählt.")
            return
        rec_id = int(self.tbl.item(row, 0).text())
        firma = self.in_firma.text().strip()
        position = self.in_position.text().strip()
        if not firma or not position:
            QMessageBox.warning(self, "Hinweis", "Firma und Position sind Pflicht.")
            return
        datum = self.in_datum.date().toString("yyyy-MM-dd")
        status = self.in_status.currentText()
        anspr = self.in_anspr.text().strip()
        notizen = self.in_notiz.toPlainText().strip()
        with self.con:
            self.con.execute(
                "UPDATE apps SET firma=?, position=?, ansprechpartner=?, datum=?, status=?, notizen=? WHERE id=?",
                (firma, position, anspr, datum, status, notizen, rec_id)
            )
        self.refresh(select_id=rec_id)

    def delete_current(self):
        row = self.tbl.currentRow()
        if row < 0:
            return
        rec_id = int(self.tbl.item(row, 0).text())
        if QMessageBox.question(self, "Löschen", f"Eintrag {rec_id} wirklich löschen?") == QMessageBox.Yes:
            with self.con:
                self.con.execute("DELETE FROM apps WHERE id=?", (rec_id,))
            self.refresh()

    def export_csv(self):
        path, _ = QFileDialog.getSaveFileName(self, "CSV exportieren", "bewerbungen.csv", "CSV (*.csv)")
        if not path:
            return
        # aktuelle Ansicht exportieren
        rows = self.tbl.rowCount()
        cols = self.tbl.columnCount()
        with open(path, "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f, delimiter=";")
            headers = [self.tbl.horizontalHeaderItem(c).text() for c in range(cols)]
            w.writerow(headers)
            for r in range(rows):
                w.writerow([self.tbl.item(r, c).text() if self.tbl.item(r, c) else "" for c in range(cols)])
        QMessageBox.information(self, "Export", "CSV exportiert.")

    def refresh(self, select_id=None):
        filters = {"status": self.f_status.currentText(), "firma": self.f_firma.text().strip()}
        search = self.f_search.text().strip()
        rows = fetch_all(self.con, filters, search)
        self.tbl.setSortingEnabled(False)
        self.tbl.setRowCount(0)
        for row in rows:
            r = self.tbl.rowCount()
            self.tbl.insertRow(r)
            for c, itm in enumerate(row_to_items(row)):
                # ID zentrieren, Datum zentrieren
                if c in (0, 4):
                    itm.setTextAlignment(Qt.AlignCenter)
                self.tbl.setItem(r, c, itm)
        self.tbl.setSortingEnabled(True)
        self.show_reminders(rows)

        if select_id:
            for r in range(self.tbl.rowCount()):
                if int(self.tbl.item(r, 0).text()) == select_id:
                    self.tbl.selectRow(r)
                    break
        else:
            self.tbl.clearSelection()
            self.clear_form()

    def show_reminders(self, rows):
        days = self.f_days.value()
        today = dt.date.today()
        due = 0
        for row in rows:
            if row["status"] == "Gesendet":
                try:
                    d = dt.date.fromisoformat(row["datum"])
                    if (today - d).days >= days:
                        due += 1
                except Exception:
                    pass
        self.lbl_rem.setText(f"Erinnerungen fällig: {due}")

    def sync_form_from_selection(self):
        row = self.tbl.currentRow()
        if row < 0:
            return
        self.in_firma.setText(self.tbl.item(row, 1).text())
        self.in_position.setText(self.tbl.item(row, 2).text())
        self.in_anspr.setText(self.tbl.item(row, 3).text())
        try:
            d = QDate.fromString(self.tbl.item(row, 4).text(), "yyyy-MM-dd")
            if d.isValid():
                self.in_datum.setDate(d)
        except Exception:
            pass
        idx = self.in_status.findText(self.tbl.item(row, 5).text())
        self.in_status.setCurrentIndex(idx if idx >= 0 else 0)
        self.in_notiz.setPlainText(self.tbl.item(row, 6).text())

    def clear_form(self):
        self.in_firma.clear(); self.in_position.clear(); self.in_anspr.clear()
        self.in_datum.setDate(QDate.currentDate())
        self.in_status.setCurrentIndex(0)
        self.in_notiz.clear()

if __name__ == "__main__":
    app = QApplication(sys.argv)
    w = App()
    w.resize(1150, 520)
    w.show()
    sys.exit(app.exec())

