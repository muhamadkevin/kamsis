package main

import (
	"database/sql"
	"fmt"
	"html/template"
	"net/http"
	"strconv"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"golang.org/x/crypto/bcrypt"
)

var db *sql.DB
var tmpl = template.Must(template.ParseGlob("templates/*.html"))
var sessions = map[string]string{}

type User struct {
	ID         int
	Nama       string
	NIM        string
	AsalKampus string
	Email      string
	Umur       int
	Password   string
}

func initDB() {
	var err error
	dsn := "appuser:strongpassword123@tcp(db:3306)/kamsis?parseTime=true"

	// Retry sampai MySQL siap (max 30x, interval 2 detik = 60 detik)
	for i := 1; i <= 30; i++ {
		db, err = sql.Open("mysql", dsn)
		if err != nil {
			fmt.Printf("[%d/30] Gagal open DB: %s\n", i, err.Error())
			time.Sleep(2 * time.Second)
			continue
		}
		err = db.Ping()
		if err == nil {
			fmt.Println("Database connected!")
			return
		}
		fmt.Printf("[%d/30] Menunggu MySQL siap... %s\n", i, err.Error())
		db.Close()
		time.Sleep(2 * time.Second)
	}
	panic("Gagal connect DB setelah 30 percobaan: " + err.Error())
}

func homeHandler(w http.ResponseWriter, r *http.Request) {
	http.Redirect(w, r, "/login", http.StatusSeeOther)
}

func registerHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method == "GET" {
		tmpl.ExecuteTemplate(w, "register.html", nil)
		return
	}

	nama       := r.FormValue("nama")
	nim        := r.FormValue("nim")
	asalKampus := r.FormValue("asal_kampus")
	email      := r.FormValue("email")
	umurStr    := r.FormValue("umur")
	password   := r.FormValue("password")

	if nama == "" || nim == "" || asalKampus == "" || email == "" || umurStr == "" || password == "" {
		tmpl.ExecuteTemplate(w, "register.html", map[string]string{"Error": "Semua field wajib diisi!"})
		return
	}

	// Anti buffer overflow
	if len(nama) > 100 || len(nim) > 20 || len(email) > 100 || len(password) > 128 {
		tmpl.ExecuteTemplate(w, "register.html", map[string]string{"Error": "Input melebihi batas karakter!"})
		return
	}

	umur, err := strconv.Atoi(umurStr)
	if err != nil || umur < 1 || umur > 100 {
		tmpl.ExecuteTemplate(w, "register.html", map[string]string{"Error": "Umur tidak valid!"})
		return
	}

	// Salt + Hash dengan bcrypt
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		http.Error(w, "Server error", 500)
		return
	}

	// Anti SQL Injection — prepared statement
	_, err = db.Exec(
		`INSERT INTO users (nama, nim, asal_kampus, email, umur, password) VALUES (?, ?, ?, ?, ?, ?)`,
		nama, nim, asalKampus, email, umur, string(hashedPassword),
	)
	if err != nil {
		tmpl.ExecuteTemplate(w, "register.html", map[string]string{"Error": "NIM atau Email sudah terdaftar!"})
		return
	}

	http.Redirect(w, r, "/login?success=1", http.StatusSeeOther)
}

func loginHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method == "GET" {
		data := map[string]string{}
		if r.URL.Query().Get("success") == "1" {
			data["Success"] = "Registrasi berhasil! Silakan login."
		}
		tmpl.ExecuteTemplate(w, "login.html", data)
		return
	}

	nim      := r.FormValue("nim")
	password := r.FormValue("password")

	if nim == "" || password == "" {
		tmpl.ExecuteTemplate(w, "login.html", map[string]string{"Error": "NIM dan password wajib diisi!"})
		return
	}

	// Anti SQL Injection — prepared statement
	var user User
	err := db.QueryRow(
		`SELECT id, nama, nim, password FROM users WHERE nim = ?`, nim,
	).Scan(&user.ID, &user.Nama, &user.NIM, &user.Password)

	if err != nil {
		tmpl.ExecuteTemplate(w, "login.html", map[string]string{"Error": "NIM atau password salah!"})
		return
	}

	// Verifikasi hash
	err = bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(password))
	if err != nil {
		tmpl.ExecuteTemplate(w, "login.html", map[string]string{"Error": "NIM atau password salah!"})
		return
	}

	sessionID := fmt.Sprintf("sess-%d", user.ID)
	sessions[sessionID] = user.Nama

	// Cookie HTTPS-only
	http.SetCookie(w, &http.Cookie{
		Name:     "session_id",
		Value:    sessionID,
		Path:     "/",
		HttpOnly: true,
		Secure:   true,    // ← hanya kirim via HTTPS
		SameSite: http.SameSiteStrictMode,
	})

	http.Redirect(w, r, "/dashboard", http.StatusSeeOther)
}

func dashboardHandler(w http.ResponseWriter, r *http.Request) {
	cookie, err := r.Cookie("session_id")
	if err != nil {
		http.Redirect(w, r, "/login", http.StatusSeeOther)
		return
	}
	nama, ok := sessions[cookie.Value]
	if !ok {
		http.Redirect(w, r, "/login", http.StatusSeeOther)
		return
	}

	// Anti XSS — Go template otomatis escape output
	tmpl.ExecuteTemplate(w, "dashboard.html", map[string]string{"Nama": nama})
}

func logoutHandler(w http.ResponseWriter, r *http.Request) {
	cookie, err := r.Cookie("session_id")
	if err == nil {
		delete(sessions, cookie.Value)
	}
	http.SetCookie(w, &http.Cookie{
		Name:   "session_id",
		Value:  "",
		MaxAge: -1,
	})
	http.Redirect(w, r, "/login", http.StatusSeeOther)
}

func main() {
	initDB()
	defer db.Close()

	http.HandleFunc("/", homeHandler)
	http.HandleFunc("/register", registerHandler)
	http.HandleFunc("/login", loginHandler)
	http.HandleFunc("/dashboard", dashboardHandler)
	http.HandleFunc("/logout", logoutHandler)

	fmt.Println("🚀 Server HTTPS jalan di https://localhost:443")

	// Redirect HTTP ke HTTPS
	go http.ListenAndServe("0.0.0.0:80", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, "https://"+r.Host+r.URL.String(), http.StatusMovedPermanently)
	}))

	// HTTPS dengan self-signed cert
	err := http.ListenAndServeTLS("0.0.0.0:443", "/app/certs/cert.pem", "/app/certs/key.pem", nil)
	if err != nil {
		panic(err)
	}
}