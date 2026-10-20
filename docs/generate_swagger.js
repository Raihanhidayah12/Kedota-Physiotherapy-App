const fs = require('fs');
const path = require('path');
const YAML = require('yaml');

const openApiSpec = {
  openapi: "3.0.3",
  info: {
    title: "Kedota Physiotherapy App - API Documentation & Swagger",
    version: "1.0.0",
    description: `Dokumentasi API lengkap untuk aplikasi **Kedota Physiotherapy**, mencakup seluruh Screen/Halaman aplikasi (Splash, Onboarding, Sign In, Sign Up, Verifikasi OTP & PIN, Home Dashboard, Alur Reservasi Layanan, Detail & Riwayat Janji Temu, Reschedule Jadwal, Pelunasan Pembayaran, Edit Profil, Ubah Kontak & PIN, hingga Logging Error).

Dokumentasi ini mencakup:
- Seluruh metode HTTP: **GET, POST, PATCH, PUT, DELETE**.
- Seluruh tabel database Supabase beserta setiap kolom dan tipe datanya:
  - \`profiles\` (21 kolom)
  - \`appointments\` (39 kolom)
  - \`error_logs\` (8 kolom)
  - \`storage.objects\` (\`profile-photos\` bucket)
- Stored Procedures (RPC PostgreSQL): \`expire_overdue_appointments\`, \`reschedule_appointment\`, \`settle_appointment_payment\`.
- Supabase Edge Functions: \`update-pin\` (AES-GCM encrypted) dan \`client-error-log\`.
- Supabase Auth Service endpoints (OAuth Google/Apple, SMS/Email OTP, Email/PIN Password).`
  },
  servers: [
    {
      url: "https://wwmctqhbqpsbkyxkeaqv.supabase.co",
      description: "Supabase Cloud Production Server"
    },
    {
      url: "http://localhost:54321",
      description: "Supabase Local Development Server"
    }
  ],
  tags: [
    {
      name: "Screen: Splash & App Init",
      description: "Pengecekan sesi login, token refresh, dan verifikasi kelengkapan profil pengguna saat aplikasi pertama kali dibuka."
    },
    {
      name: "Screen: Sign In",
      description: "Autentikasi pengguna melalui Nomor Telepon, Google Sign-In (OAuth/ID Token), dan Apple Sign-In."
    },
    {
      name: "Screen: OTP Verification",
      description: "Pengiriman dan verifikasi One-Time Password (OTP) 6-digit via SMS/WhatsApp atau Email."
    },
    {
      name: "Screen: PIN Verification & Forgot PIN",
      description: "Verifikasi 6-digit PIN transaksi/keamanan akun serta alur reset PIN lupa menggunakan validasi tanggal lahir dan OTP."
    },
    {
      name: "Screen: Profile Completion & Sign Up",
      description: "Pendaftaran akun baru dan pengisian biodata (nama, NIK, tanggal lahir, jenis kelamin, alamat, foto profil, dan generasi kode rekam medis KDT)."
    },
    {
      name: "Screen: Home & Dashboard",
      description: "Halaman utama: ringkasan profil pasien, kartu janji temu terdekat (upcoming), dan otomatisasi expired janji temu."
    },
    {
      name: "Screen: Reservation Flow",
      description: "Alur pemesanan jadwal fisioterapi (Klinik atau Home Care), pemilihan tanggal, pengecekan ketersediaan slot bebas bentrok, paket sesi, dan kalkulasi promo."
    },
    {
      name: "Screen: History & Appointment List",
      description: "Daftar riwayat reservasi janji temu dengan filter tab (Mendatang / Upcoming, Selesai / Completed, Batas Waktu / Expired, Dibatalkan / Cancelled)."
    },
    {
      name: "Screen: Appointment Detail",
      description: "Detail lengkap janji temu, rekam medis klinis (skor nyeri VAS, ROM, MMT, ODI), SIPF terapis, pembatalan janji temu, dan invoice."
    },
    {
      name: "Screen: Reschedule Appointment",
      description: "Fitur pemindahan jadwal janji temu dengan validasi slot waktu tersedia dan penegakan batas waktu reschedule (kebijakan H-24 jam)."
    },
    {
      name: "Screen: Settle Payment",
      description: "Pelunasan sisa pembayaran bagi reservasi dengan sistem DP (Deposit Plan)."
    },
    {
      name: "Screen: Notifications",
      description: "Pusat notifikasi status jadwal, peringatan jatuh tempo, dan preferensi pemberitahuan pengguna."
    },
    {
      name: "Screen: Settings & Profile",
      description: "Ringkasan profil akun, pengaturan privasi, ganti bahasa, logout, serta penghapusan akun."
    },
    {
      name: "Screen: Edit Profile",
      description: "Pembaruan informasi profil pengguna dan upload/pergantian avatar foto profil."
    },
    {
      name: "Screen: Change Contact",
      description: "Pergantian nomor telepon atau email terdaftar disertai verifikasi OTP keamanan."
    },
    {
      name: "Screen: Change PIN",
      description: "Pembaruan 6-digit PIN keamanan melalui Edge Function terenkripsi AES-GCM."
    },
    {
      name: "Storage: Profile Photos",
      description: "Supabase Storage API untuk upload, unduh, dan hapus foto profil pengguna."
    },
    {
      name: "System: Edge Functions & Logging",
      description: "Edge Functions untuk enkripsi data sensitif dan logging otomatis server error 5xx dari aplikasi Flutter."
    }
  ],
  paths: {
    // -------------------------------------------------------------------------
    // AUTH ENDPOINTS
    // -------------------------------------------------------------------------
    "/auth/v1/token": {
      post: {
        tags: ["Screen: Sign In", "Screen: PIN Verification & Forgot PIN", "Screen: Splash & App Init"],
        summary: "Auth Token (Password, Google/Apple ID Token, atau Refresh Token)",
        description: `Endpoint utama autentikasi Supabase Auth.
Mendukung 3 metode \`grant_type\` melalui query parameter:
- \`password\`: Sign In dengan email (atau \`{phone}@kedota.local\`) dan PIN 6-digit.
- \`id_token\`: Sign In via Google Sign-In SDK atau Apple Sign-In.
- \`refresh_token\`: Memperbarui token sesi pengguna yang telah kedaluwarsa.`,
        parameters: [
          {
            name: "grant_type",
            in: "query",
            required: true,
            description: "Tipe otentikasi yang diminta",
            schema: {
              type: "string",
              enum: ["password", "id_token", "refresh_token"],
              example: "password"
            }
          }
        ],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                oneOf: [
                  { $ref: "#/components/schemas/AuthPasswordLoginRequest" },
                  { $ref: "#/components/schemas/AuthIdTokenLoginRequest" },
                  { $ref: "#/components/schemas/AuthRefreshTokenRequest" }
                ]
              }
            }
          }
        },
        responses: {
          "200": {
            description: "Login berhasil, mengembalikan token sesi pengguna.",
            content: {
              "application/json": {
                schema: {
                  $ref: "#/components/schemas/AuthSessionResponse"
                }
              }
            }
          },
          "400": {
            description: "Kredensial tidak valid, PIN salah, atau token kedaluwarsa.",
            content: {
              "application/json": {
                schema: {
                  $ref: "#/components/schemas/ErrorResponse"
                }
              }
            }
          }
        }
      }
    },
    "/auth/v1/signup": {
      post: {
        tags: ["Screen: Profile Completion & Sign Up"],
        summary: "Daftar Akun Baru (Sign Up)",
        description: "Mendaftarkan identitas akun baru ke Supabase Auth dengan email/phone, password PIN, dan user metadata.",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                $ref: "#/components/schemas/AuthSignUpRequest"
              }
            }
          }
        },
        responses: {
          "200": {
            description: "Pendaftaran user auth berhasil.",
            content: {
              "application/json": {
                schema: {
                  $ref: "#/components/schemas/AuthSessionResponse"
                }
              }
            }
          },
          "422": {
            description: "Email atau nomor telepon sudah terdaftar.",
            content: {
              "application/json": {
                schema: {
                  $ref: "#/components/schemas/ErrorResponse"
                }
              }
            }
          }
        }
      }
    },
    "/auth/v1/otp": {
      post: {
        tags: ["Screen: OTP Verification", "Screen: PIN Verification & Forgot PIN", "Screen: Change Contact"],
        summary: "Kirim Kode OTP (SMS / WhatsApp / Email)",
        description: "Mengirimkan 6-digit kode One-Time Password ke nomor telepon atau email pengguna untuk verifikasi login, lupa PIN, atau ganti kontak.",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                $ref: "#/components/schemas/SendOtpRequest"
              }
            }
          }
        },
        responses: {
          "200": {
            description: "Kode OTP berhasil dikirim.",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    message: { type: "string", example: "OTP sent successfully" }
                  }
                }
              }
            }
          },
          "429": {
            description: "Rate limit: terlalu banyak permintaan OTP dalam waktu singkat.",
            content: {
              "application/json": {
                schema: {
                  $ref: "#/components/schemas/ErrorResponse"
                }
              }
            }
          }
        }
      }
    },
    "/auth/v1/verify": {
      post: {
        tags: ["Screen: OTP Verification", "Screen: Change Contact"],
        summary: "Verifikasi Kode OTP",
        description: "Memvalidasi kode 6 digit OTP yang dimasukkan pengguna pada screen verifikasi.",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                $ref: "#/components/schemas/VerifyOtpRequest"
              }
            }
          }
        },
        responses: {
          "200": {
            description: "Verifikasi OTP sukses.",
            content: {
              "application/json": {
                schema: {
                  $ref: "#/components/schemas/AuthSessionResponse"
                }
              }
            }
          },
          "400": {
            description: "Kode OTP salah atau telah kedaluwarsa.",
            content: {
              "application/json": {
                schema: {
                  $ref: "#/components/schemas/ErrorResponse"
                }
              }
            }
          }
        }
      }
    },
    "/auth/v1/user": {
      get: {
        tags: ["Screen: Splash & App Init", "Screen: Settings & Profile"],
        summary: "Get Current Auth User",
        description: "Mengambil data identitas pengguna yang sedang terautentikasi berdasarkan Bearer Access Token.",
        security: [{ BearerAuth: [] }, { ApiKeyAuth: [] }],
        responses: {
          "200": {
            description: "Data user auth aktif.",
            content: {
              "application/json": {
                schema: {
                  $ref: "#/components/schemas/AuthUser"
                }
              }
            }
          },
          "401": {
            description: "Unauthenticated / token expired."
          }
        }
      },
      put: {
        tags: ["Screen: Settings & Profile", "Screen: Change Contact"],
        summary: "Update Auth User Attributes",
        description: "Memperbarui atribut internal user auth seperti email akun atau password.",
        security: [{ BearerAuth: [] }, { ApiKeyAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                properties: {
                  email: { type: "string", format: "email" },
                  password: { type: "string" },
                  data: { type: "object", description: "User metadata" }
                }
              }
            }
          }
        },
        responses: {
          "200": {
            description: "Data akun auth berhasil diperbarui.",
            content: {
              "application/json": {
                schema: {
                  $ref: "#/components/schemas/AuthUser"
                }
              }
            }
          }
        }
      }
    },
    "/auth/v1/logout": {
      post: {
        tags: ["Screen: Settings & Profile"],
        summary: "Logout / Keluar Sesi",
        description: "Membatalkan sesi token aktif pengguna dari server dan perangkat.",
        security: [{ BearerAuth: [] }, { ApiKeyAuth: [] }],
        responses: {
          "204": {
            description: "Berhasil keluar dari sesi."
          }
        }
      }
    },

    // -------------------------------------------------------------------------
    // REST API: PROFILES TABLE (CRUD)
    // -------------------------------------------------------------------------
    "/rest/v1/profiles": {
      get: {
        tags: ["Screen: Splash & App Init", "Screen: Sign In", "Screen: Home & Dashboard", "Screen: Settings & Profile", "Screen: Edit Profile"],
        summary: "GET Profiles (Query / Filter / Ambil Data Profil)",
        description: `Mengambil data baris dari tabel \`public.profiles\`.
Digunakan pada:
- **Splash Screen**: Verifikasi profil user aktif (\`id=eq.{userId}\`) dan mengecek status \`is_profile_complete\`.
- **Sign In Screen**: Memeriksa apakah nomor telepon terdaftar (\`phone=eq.{normalizedPhone}\`) dan status akun.
- **Home & Dashboard**: Mengambil nama pasien, URL avatar, dan kode rekam medis (\`medical_code\`).
- **Edit Profile**: Mengambil seluruh detail kolom profil untuk ditampilkan di form edit.`,
        security: [{ BearerAuth: [] }, { ApiKeyAuth: [] }],
        parameters: [
          {
            name: "id",
            in: "query",
            description: "Filter ID pengguna (UUID auth)",
            schema: { type: "string", example: "eq.550e8400-e29b-41d4-a716-446655440000" }
          },
          {
            name: "phone",
            in: "query",
            description: "Filter nomor telepon terdaftar",
            schema: { type: "string", example: "eq.+6281234567890" }
          },
          {
            name: "email",
            in: "query",
            description: "Filter email kontak",
            schema: { type: "string", example: "eq.budi@example.com" }
          },
          {
            name: "select",
            in: "query",
            description: "Kolom-kolom yang ingin diambil (PostgREST syntax)",
            schema: { type: "string", default: "*" }
          }
        ],
        responses: {
          "200": {
            description: "Daftar profil yang cocok.",
            content: {
              "application/json": {
                schema: {
                  type: "array",
                  items: {
                    $ref: "#/components/schemas/Profile"
                  }
                }
              }
            }
          }
        }
      },
      post: {
        tags: ["Screen: Profile Completion & Sign Up"],
        summary: "POST Profiles (Insert Profil Baru)",
        description: `Membuat record baris profil baru pada tabel \`public.profiles\` saat pengguna menyelesaikan registrasi akun.
Menyimpan seluruh data biodata pasien termasuk hash PIN dan kode rekam medis unik.`,
        security: [{ BearerAuth: [] }, { ApiKeyAuth: [] }],
        parameters: [
          {
            name: "Prefer",
            in: "header",
            description: "Preferensi PostgREST untuk mengembalikan data hasil insert",
            schema: { type: "string", example: "return=representation" }
          }
        ],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                $ref: "#/components/schemas/ProfileInsertRequest"
              }
            }
          }
        },
        responses: {
          "201": {
            description: "Profil berhasil dibuat.",
            content: {
              "application/json": {
                schema: {
                  type: "array",
                  items: {
                    $ref: "#/components/schemas/Profile"
                  }
                }
              }
            }
          },
          "409": {
            description: "Duplikasi data unik (misalnya medical_code atau ID sudah ada)."
          }
        }
      },
      patch: {
        tags: ["Screen: Edit Profile", "Screen: Change Contact", "Screen: PIN Verification & Forgot PIN"],
        summary: "PATCH Profiles (Update Kolom Profil Pengguna)",
        description: `Memperbarui sebagian kolom pada baris profil pengguna di tabel \`public.profiles\`.
Digunakan untuk:
- Mengubah Nama, Tanggal Lahir, Jenis Kelamin, NIK, Alamat, atau URL Foto Profil.
- Memperbarui Nomor Telepon (\`phone\` & \`phone_changed_at\`).
- Memperbarui Email Kontak dan status \`email_verified\`.
- Memperbarui timestamp login terakhir (\`last_login_at\`).`,
        security: [{ BearerAuth: [] }, { ApiKeyAuth: [] }],
        parameters: [
          {
            name: "id",
            in: "query",
            required: true,
            description: "Filter ID baris pengguna yang diupdate (e.g. `eq.{userId}`)",
            schema: { type: "string", example: "eq.550e8400-e29b-41d4-a716-446655440000" }
          },
          {
            name: "Prefer",
            in: "header",
            description: "Preferensi PostgREST untuk mengembalikan data yang diperbarui",
            schema: { type: "string", example: "return=representation" }
          }
        ],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                $ref: "#/components/schemas/ProfileUpdateRequest"
              }
            }
          }
        },
        responses: {
          "200": {
            description: "Profil berhasil diperbarui.",
            content: {
              "application/json": {
                schema: {
                  type: "array",
                  items: {
                    $ref: "#/components/schemas/Profile"
                  }
                }
              }
            }
          }
        }
      },
      delete: {
        tags: ["Screen: Settings & Profile"],
        summary: "DELETE Profiles (Deaktivasi / Hapus Akun)",
        description: `Menghapus atau menonaktifkan akun profil pengguna dari database (\`public.profiles\`). Biasanya dipicu dari opsi Hapus Akun pada Settings.`,
        security: [{ BearerAuth: [] }, { ApiKeyAuth: [] }],
        parameters: [
          {
            name: "id",
            in: "query",
            required: true,
            description: "Filter ID pengguna yang akan dihapus",
            schema: { type: "string", example: "eq.550e8400-e29b-41d4-a716-446655440000" }
          }
        ],
        responses: {
          "204": {
            description: "Profil berhasil dihapus."
          }
        }
      }
    },

    // -------------------------------------------------------------------------
    // REST API: APPOINTMENTS TABLE (CRUD)
    // -------------------------------------------------------------------------
    "/rest/v1/appointments": {
      get: {
        tags: [
          "Screen: Home & Dashboard",
          "Screen: History & Appointment List",
          "Screen: Appointment Detail",
          "Screen: Reservation Flow",
          "Screen: Notifications"
        ],
        summary: "GET Appointments (List / Filter / Detail / Cek Slot Waktu)",
        description: `Mengambil data dari tabel \`public.appointments\`.
Mendukung query parameter PostgREST:
- **Cek Slot Waktu**: \`appointment_date=eq.{date}&appointment_time=eq.{time}&service_type=eq.{service}&clinic_name=eq.{clinic}&appointment_status=neq.cancelled\`
- **Home Dashboard (Upcoming)**: \`booker_id=eq.{userId}&appointment_status=eq.upcoming&order=appointment_date.asc,appointment_time.asc&limit=1\`
- **Riwayat Lengkap**: \`booker_id=eq.{userId}&order=appointment_date.desc,appointment_time.desc\`
- **Filter Tab Status**: \`booker_id=eq.{userId}&appointment_status=eq.{status}\`
- **Detail Janji Temu**: \`id=eq.{appointmentId}\``,
        security: [{ BearerAuth: [] }, { ApiKeyAuth: [] }],
        parameters: [
          {
            name: "id",
            in: "query",
            description: "Filter berdasarkan ID Appointment",
            schema: { type: "string", example: "eq.8f1e582e-64d5-455b-9d41-789a12bc34de" }
          },
          {
            name: "booker_id",
            in: "query",
            description: "Filter berdasarkan ID pemesan (auth.uid)",
            schema: { type: "string", example: "eq.550e8400-e29b-41d4-a716-446655440000" }
          },
          {
            name: "appointment_status",
            in: "query",
            description: "Filter status appointment: upcoming, completed, expired, cancelled (mendukung neq.cancelled)",
            schema: { type: "string", example: "eq.upcoming" }
          },
          {
            name: "appointment_date",
            in: "query",
            description: "Filter tanggal janji temu (YYYY-MM-DD)",
            schema: { type: "string", example: "eq.2026-10-25" }
          },
          {
            name: "appointment_time",
            in: "query",
            description: "Filter jam janji temu (HH:MM:SS)",
            schema: { type: "string", example: "eq.10:00:00" }
          },
          {
            name: "service_type",
            in: "query",
            description: "Filter jenis layanan (Klinik atau Home Care)",
            schema: { type: "string", example: "eq.Klinik" }
          },
          {
            name: "clinic_name",
            in: "query",
            description: "Filter cabang klinik",
            schema: { type: "string", example: "eq.Klinik Kedota Malang Tunggulwulung" }
          },
          {
            name: "order",
            in: "query",
            description: "Urutan sorting data (e.g. `appointment_date.desc`)",
            schema: { type: "string", example: "appointment_date.desc,appointment_time.desc" }
          },
          {
            name: "limit",
            in: "query",
            description: "Batasan jumlah baris yang diambil",
            schema: { type: "integer", example: 1 }
          },
          {
            name: "select",
            in: "query",
            description: "Daftar kolom yang ingin diambil",
            schema: { type: "string", default: "*" }
          }
        ],
        responses: {
          "200": {
            description: "Daftar record appointment.",
            content: {
              "application/json": {
                schema: {
                  type: "array",
                  items: {
                    $ref: "#/components/schemas/Appointment"
                  }
                }
              }
            }
          }
        }
      },
      post: {
        tags: ["Screen: Reservation Flow"],
        summary: "POST Appointments (Buat Reservasi Baru)",
        description: `Membuat data reservasi janji temu baru pada tabel \`public.appointments\`.
Menyimpan informasi lengkap pasien, jenis layanan (Klinik/Home Care), jadwal tanggal & waktu, paket sesi, preferensi terapis, rincian biaya (base price, travel fee, diskon), dan metode pembayaran.
Trigger database \`prevent_appointment_slot_conflict\` akan secara otomatis memverifikasi dan mencegah slot waktu ganda yang bentrok.`,
        security: [{ BearerAuth: [] }, { ApiKeyAuth: [] }],
        parameters: [
          {
            name: "Prefer",
            in: "header",
            description: "Kembalikan representasi record yang di-insert",
            schema: { type: "string", example: "return=representation" }
          }
        ],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                $ref: "#/components/schemas/AppointmentInsertRequest"
              }
            }
          }
        },
        responses: {
          "201": {
            description: "Reservasi janji temu berhasil dibuat.",
            content: {
              "application/json": {
                schema: {
                  type: "array",
                  items: {
                    $ref: "#/components/schemas/Appointment"
                  }
                }
              }
            }
          },
          "409": {
            description: "Slot waktu dan tanggal yang dipilih sudah terisi oleh pasien lain (conflict).",
            content: {
              "application/json": {
                schema: {
                  $ref: "#/components/schemas/ErrorResponse"
                }
              }
            }
          }
        }
      },
      patch: {
        tags: ["Screen: Appointment Detail", "Screen: Reservation Flow"],
        summary: "PATCH Appointments (Update / Batalkan Janji Temu)",
        description: `Memperbarui sebagian data janji temu.
Digunakan untuk:
- **Batalkan Janji Temu**: Mengubah \`appointment_status\` menjadi \`cancelled\`.
- **Backfill / Persist Booking Code**: Mengisi kolom \`booking_code\` dengan kode EMR canonical.
- **Update Evaluasi Klinis**: Memasukkan skor evaluasi medis pasca-terapi (\`clinical_note\`, \`vas_score\`, \`rom_score\`, \`mmt_score\`, \`odi_score\`, \`therapist_recommendation\`).`,
        security: [{ BearerAuth: [] }, { ApiKeyAuth: [] }],
        parameters: [
          {
            name: "id",
            in: "query",
            required: true,
            description: "Filter ID appointment yang diupdate",
            schema: { type: "string", example: "eq.8f1e582e-64d5-455b-9d41-789a12bc34de" }
          },
          {
            name: "Prefer",
            in: "header",
            schema: { type: "string", example: "return=representation" }
          }
        ],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                $ref: "#/components/schemas/AppointmentUpdateRequest"
              }
            }
          }
        },
        responses: {
          "200": {
            description: "Data appointment berhasil diubah.",
            content: {
              "application/json": {
                schema: {
                  type: "array",
                  items: {
                    $ref: "#/components/schemas/Appointment"
                  }
                }
              }
            }
          }
        }
      },
      delete: {
        tags: ["Screen: Appointment Detail"],
        summary: "DELETE Appointments (Hapus Data Janji Temu)",
        description: "Menghapus record appointment dari database.",
        security: [{ BearerAuth: [] }, { ApiKeyAuth: [] }],
        parameters: [
          {
            name: "id",
            in: "query",
            required: true,
            description: "Filter ID appointment yang dihapus",
            schema: { type: "string", example: "eq.8f1e582e-64d5-455b-9d41-789a12bc34de" }
          }
        ],
        responses: {
          "204": {
            description: "Record appointment berhasil dihapus."
          }
        }
      }
    },

    // -------------------------------------------------------------------------
    // STORED PROCEDURES / RPC FUNCTIONS
    // -------------------------------------------------------------------------
    "/rest/v1/rpc/expire_overdue_appointments": {
      post: {
        tags: ["Screen: Home & Dashboard", "Screen: History & Appointment List"],
        summary: "RPC: Expire Overdue Appointments",
        description: `Memanggil fungsi database PostgreSQL \`public.expire_overdue_appointments()\`.
Mengecek semua janji temu berstatus \`upcoming\` milik user aktif yang jadwalnya telah lewat lebih dari 15 menit, lalu mengubah statusnya menjadi \`expired\`.
Mengembalikan daftar janji temu yang statusnya diperbarui.`,
        security: [{ BearerAuth: [] }, { ApiKeyAuth: [] }],
        requestBody: {
          required: false,
          content: {
            "application/json": {
              schema: {
                type: "object",
                properties: {}
              }
            }
          }
        },
        responses: {
          "200": {
            description: "Daftar appointment yang telah diubah statusnya menjadi expired.",
            content: {
              "application/json": {
                schema: {
                  type: "array",
                  items: {
                    $ref: "#/components/schemas/Appointment"
                  }
                }
              }
            }
          }
        }
      }
    },
    "/rest/v1/rpc/reschedule_appointment": {
      post: {
        tags: ["Screen: Reschedule Appointment"],
        summary: "RPC: Reschedule Appointment",
        description: `Memanggil stored procedure \`public.reschedule_appointment(p_appointment_id, p_appointment_date, p_appointment_time)\`.
Memindahkan jadwal janji temu dengan aturan bisnis:
1. Memverifikasi kepemilikan appointment (\`booker_id = auth.uid()\`).
2. Menegakkan jendela reschedule:
   - Jika belum bayar penuh / unexpired: minimal H-24 jam sebelum jadwal awal.
   - Jika sudah bayar (paid) & berstatus expired: diperbolehkan dalam rentang 24 jam setelah jadwal terlewat.
3. Memverifikasi bahwa slot baru tidak bertabrakan dengan pasien lain.
4. Memperbarui tanggal, jam, dan mengembalikan status ke \`upcoming\`.`,
        security: [{ BearerAuth: [] }, { ApiKeyAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                $ref: "#/components/schemas/RescheduleRpcRequest"
              }
            }
          }
        },
        responses: {
          "200": {
            description: "Janji temu berhasil dijadwalkan ulang.",
            content: {
              "application/json": {
                schema: {
                  $ref: "#/components/schemas/Appointment"
                }
              }
            }
          },
          "400": {
            description: "Jadwal berada di luar jendela yang diperbolehkan atau parameter tidak valid.",
            content: {
              "application/json": {
                schema: {
                  $ref: "#/components/schemas/ErrorResponse"
                }
              }
            }
          },
          "409": {
            description: "Slot tanggal & waktu baru bentrok dengan jadwal lain.",
            content: {
              "application/json": {
                schema: {
                  $ref: "#/components/schemas/ErrorResponse"
                }
              }
            }
          }
        }
      }
    },
    "/rest/v1/rpc/settle_appointment_payment": {
      post: {
        tags: ["Screen: Settle Payment", "Screen: Appointment Detail"],
        summary: "RPC: Settle Appointment Payment",
        description: `Memanggil stored procedure \`public.settle_appointment_payment(p_appointment_id, p_payment_method)\`.
Melunasi sisa tagihan janji temu berstatus \`pending\` (misalnya sisa pembayaran paket atau deposit):
- Mengubah \`payment_status\` menjadi \`paid\`.
- Mengatur metode pembayaran pelunasan \`payment_method\`.
- Mengatur sisa tagihan \`amount_due\` menjadi \`0\`.`,
        security: [{ BearerAuth: [] }, { ApiKeyAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                $ref: "#/components/schemas/SettlePaymentRpcRequest"
              }
            }
          }
        },
        responses: {
          "200": {
            description: "Pembayaran berhasil dilunasi.",
            content: {
              "application/json": {
                schema: {
                  $ref: "#/components/schemas/Appointment"
                }
              }
            }
          },
          "404": {
            description: "Appointment tidak ditemukan atau tidak memiliki sisa pembayaran berstatus pending."
          }
        }
      }
    },

    // -------------------------------------------------------------------------
    // EDGE FUNCTIONS
    // -------------------------------------------------------------------------
    "/functions/v1/update-pin": {
      post: {
        tags: ["Screen: Change PIN", "Screen: PIN Verification & Forgot PIN", "System: Edge Functions & Logging"],
        summary: "Edge Function: Update User Security PIN",
        description: `Memperbarui 6-digit PIN keamanan pengguna secara aman menggunakan payload terenkripsi AES-GCM 256-bit dan tanda tangan HMAC SHA-256 (\`X-Encrypted: 1\`).
Menerima payload yang telah didekripsi di sisi server edge:
\`{ profile_id, new_pin_hash, new_pin }\`.
Memvalidasi token otentikasi Bearer JWT, memastikan pengguna hanya bisa mengubah PIN miliknya sendiri, dan memperbarui \`pin_hash\` di tabel \`public.profiles\`.`,
        security: [{ BearerAuth: [] }, { ApiKeyAuth: [] }],
        parameters: [
          {
            name: "X-Encrypted",
            in: "header",
            required: true,
            description: "Flag penanda bahwa request body terenkripsi rest_crypto",
            schema: { type: "string", example: "1" }
          }
        ],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                $ref: "#/components/schemas/RestCryptoEnvelope"
              }
            }
          }
        },
        responses: {
          "200": {
            description: "PIN berhasil diperbarui.",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    success: { type: "boolean", example: true },
                    message: { type: "string", example: "PIN updated successfully" }
                  }
                }
              }
            }
          },
          "400": {
            description: "Format envelope enkripsi tidak valid atau field wajib hilang."
          },
          "403": {
            description: "Forbidden: tidak diizinkan mengubah PIN user lain."
          }
        }
      }
    },
    "/functions/v1/client-error-log": {
      post: {
        tags: ["System: Edge Functions & Logging"],
        summary: "Edge Function: Client 5xx Error Logger",
        description: `Menerima laporan kesalahan server HTTP 500-599 yang dialami oleh client Flutter.
Menuliskan log ke console Edge Function Supabase dan menyimpan rekaman ke dalam tabel \`public.error_logs\` menggunakan service_role key.`,
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                $ref: "#/components/schemas/ClientErrorLogRequest"
              }
            }
          }
        },
        responses: {
          "202": {
            description: "Error log diterima dan disimpan.",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    accepted: { type: "boolean", example: true }
                  }
                }
              }
            }
          },
          "400": {
            description: "Payload log error tidak valid (status code di luar rentang 500-599)."
          }
        }
      }
    },

    // -------------------------------------------------------------------------
    // REST API: ERROR_LOGS TABLE
    // -------------------------------------------------------------------------
    "/rest/v1/error_logs": {
      get: {
        tags: ["System: Edge Functions & Logging"],
        summary: "GET Error Logs (Admin Audit)",
        description: "Mengambil daftar riwayat error 5xx dari tabel `public.error_logs` (hanya dapat diakses oleh service_role atau admin).",
        security: [{ ApiKeyAuth: [] }],
        parameters: [
          {
            name: "order",
            in: "query",
            schema: { type: "string", example: "received_at.desc" }
          },
          {
            name: "limit",
            in: "query",
            schema: { type: "integer", example: 50 }
          }
        ],
        responses: {
          "200": {
            description: "Daftar error log.",
            content: {
              "application/json": {
                schema: {
                  type: "array",
                  items: {
                    $ref: "#/components/schemas/ErrorLog"
                  }
                }
              }
            }
          }
        }
      },
      post: {
        tags: ["System: Edge Functions & Logging"],
        summary: "POST Error Log (Direct Insert)",
        description: "Memasukkan baris error log langsung ke tabel `public.error_logs`.",
        security: [{ ApiKeyAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                $ref: "#/components/schemas/ErrorLogInsertRequest"
              }
            }
          }
        },
        responses: {
          "201": {
            description: "Log error berhasil disimpan."
          }
        }
      }
    },

    // -------------------------------------------------------------------------
    // STORAGE API: PROFILE PHOTOS BUCKET
    // -------------------------------------------------------------------------
    "/storage/v1/object/profile-photos/{userId}/{fileName}": {
      post: {
        tags: ["Storage: Profile Photos", "Screen: Edit Profile", "Screen: Profile Completion & Sign Up"],
        summary: "Upload Foto Profil",
        description: `Mengunggah file gambar avatar foto profil pengguna ke bucket Supabase Storage \`profile-photos\`.
Hanya file JPEG dan PNG dengan ukuran maksimum 50MB yang diizinkan.`,
        security: [{ BearerAuth: [] }, { ApiKeyAuth: [] }],
        parameters: [
          {
            name: "userId",
            in: "path",
            required: true,
            description: "UUID pengguna pemilik file (wajib cocok dengan auth.uid)",
            schema: { type: "string", example: "550e8400-e29b-41d4-a716-446655440000" }
          },
          {
            name: "fileName",
            in: "path",
            required: true,
            description: "Nama file gambar (misalnya avatar.jpg)",
            schema: { type: "string", example: "avatar.jpg" }
          }
        ],
        requestBody: {
          required: true,
          content: {
            "image/jpeg": {
              schema: { type: "string", format: "binary" }
            },
            "image/png": {
              schema: { type: "string", format: "binary" }
            }
          }
        },
        responses: {
          "200": {
            description: "Foto berhasil diunggah.",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    Key: { type: "string", example: "profile-photos/550e8400.../avatar.jpg" }
                  }
                }
              }
            }
          }
        }
      },
      get: {
        tags: ["Storage: Profile Photos", "Screen: Home & Dashboard", "Screen: Settings & Profile"],
        summary: "Download / Akses Foto Profil Publik",
        description: "Mengambil data gambar avatar foto profil pengguna dari public storage.",
        parameters: [
          {
            name: "userId",
            in: "path",
            required: true,
            schema: { type: "string", example: "550e8400-e29b-41d4-a716-446655440000" }
          },
          {
            name: "fileName",
            in: "path",
            required: true,
            schema: { type: "string", example: "avatar.jpg" }
          }
        ],
        responses: {
          "200": {
            description: "File gambar binary.",
            content: {
              "image/jpeg": { schema: { type: "string", format: "binary" } },
              "image/png": { schema: { type: "string", format: "binary" } }
            }
          },
          "404": {
            description: "File gambar tidak ditemukan."
          }
        }
      },
      delete: {
        tags: ["Storage: Profile Photos", "Screen: Edit Profile"],
        summary: "Hapus Foto Profil",
        description: "Menghapus file gambar avatar dari bucket `profile-photos`.",
        security: [{ BearerAuth: [] }, { ApiKeyAuth: [] }],
        parameters: [
          {
            name: "userId",
            in: "path",
            required: true,
            schema: { type: "string", example: "550e8400-e29b-41d4-a716-446655440000" }
          },
          {
            name: "fileName",
            in: "path",
            required: true,
            schema: { type: "string", example: "avatar.jpg" }
          }
        ],
        responses: {
          "200": {
            description: "Foto profil berhasil dihapus."
          }
        }
      }
    }
  },

  components: {
    securitySchemes: {
      BearerAuth: {
        type: "http",
        scheme: "bearer",
        bearerFormat: "JWT",
        description: "User Supabase Access Token (JWT) yang diperoleh setelah login/sign up."
      },
      ApiKeyAuth: {
        type: "apiKey",
        in: "header",
        name: "apikey",
        description: "Supabase Publishable Anon Key (didapat dari variabel SUPABASE_ANON_KEY)."
      }
    },
    schemas: {
      // -----------------------------------------------------------------------
      // TABLE 1: PROFILES (21 COLUMNS)
      // -----------------------------------------------------------------------
      Profile: {
        type: "object",
        description: "Skema lengkap baris tabel `public.profiles` (21 Kolom).",
        required: ["id", "signup_method", "status", "is_profile_complete", "email_verified", "created_at", "updated_at"],
        properties: {
          id: {
            type: "string",
            format: "uuid",
            description: "Primary Key yang merujuk ke tabel `auth.users(id)`",
            example: "550e8400-e29b-41d4-a716-446655440000"
          },
          phone: {
            type: "string",
            nullable: true,
            description: "Nomor telepon aktif pengguna (format standar internasional e.g. +6281234567890)",
            example: "+6281234567890"
          },
          full_name: {
            type: "string",
            nullable: true,
            description: "Nama lengkap pengguna / pasien",
            example: "Budi Santoso"
          },
          email: {
            type: "string",
            format: "email",
            nullable: true,
            description: "Alamat email kontak pengguna",
            example: "budi.santoso@gmail.com"
          },
          auth_email: {
            type: "string",
            format: "email",
            nullable: true,
            description: "Alamat email internal identitas login Supabase Auth",
            example: "081234567890@kedota.local"
          },
          pin_hash: {
            type: "string",
            nullable: true,
            description: "Hash SHA-256 dari 6-digit PIN keamanan pengguna",
            example: "8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918"
          },
          birth_date: {
            type: "string",
            format: "date",
            nullable: true,
            description: "Tanggal lahir pasien (YYYY-MM-DD)",
            example: "1995-08-17"
          },
          gender: {
            type: "string",
            nullable: true,
            enum: ["Laki-laki", "Perempuan", "Lainnya", "male", "female"],
            description: "Jenis kelamin pasien",
            example: "Laki-laki"
          },
          signup_method: {
            type: "string",
            enum: ["phone", "google", "apple"],
            default: "phone",
            description: "Metode awal pendaftaran akun",
            example: "phone"
          },
          status: {
            type: "string",
            enum: ["active", "deactivated", "recycled"],
            default: "active",
            description: "Status keaktifan akun pengguna",
            example: "active"
          },
          is_profile_complete: {
            type: "boolean",
            default: false,
            description: "Penanda apakah pengguna telah menyelesaikan tahapan onboarding & pengisian profil awal",
            example: true
          },
          medical_code: {
            type: "string",
            nullable: true,
            description: "Nomor unik Rekam Medis Elektronik Pasien (format: KDT-XXXXXXXXXXXX)",
            example: "KDT-A1B2C3D4E5F6"
          },
          email_verified: {
            type: "boolean",
            default: false,
            description: "Status apakah email pengguna sudah lolos verifikasi OTP",
            example: true
          },
          profile_photo_url: {
            type: "string",
            format: "uri",
            nullable: true,
            description: "Tautan URL publik foto profil di Supabase Storage",
            example: "https://wwmctqhbqpsbkyxkeaqv.supabase.co/storage/v1/object/public/profile-photos/550e8400.../avatar.jpg"
          },
          nik: {
            type: "string",
            nullable: true,
            description: "16 digit Nomor Induk Kependudukan (KTP) pasien",
            example: "3578011708950001"
          },
          address: {
            type: "string",
            nullable: true,
            description: "Alamat domisili lengkap pasien",
            example: "Jl. Soekarno Hatta No. 45, Lowokwaru, Kota Malang"
          },
          last_login_at: {
            type: "string",
            format: "date-time",
            nullable: true,
            description: "Waktu login terakhir pengguna",
            example: "2026-10-20T10:15:30Z"
          },
          phone_changed_at: {
            type: "string",
            format: "date-time",
            nullable: true,
            description: "Waktu terakhir nomor telepon diubah",
            example: "2026-10-18T14:22:10Z"
          },
          email_changed_at: {
            type: "string",
            format: "date-time",
            nullable: true,
            description: "Waktu terakhir alamat email diubah",
            example: "2026-10-19T09:05:00Z"
          },
          created_at: {
            type: "string",
            format: "date-time",
            description: "Waktu pembuatan record",
            example: "2026-10-01T08:00:00Z"
          },
          updated_at: {
            type: "string",
            format: "date-time",
            description: "Waktu pembaruan terakhir",
            example: "2026-10-20T10:15:30Z"
          }
        }
      },

      ProfileInsertRequest: {
        type: "object",
        required: ["id", "full_name", "phone"],
        properties: {
          id: { type: "string", format: "uuid", example: "550e8400-e29b-41d4-a716-446655440000" },
          phone: { type: "string", example: "+6281234567890" },
          full_name: { type: "string", example: "Budi Santoso" },
          email: { type: "string", format: "email", example: "budi.santoso@gmail.com" },
          auth_email: { type: "string", format: "email", example: "081234567890@kedota.local" },
          pin_hash: { type: "string", example: "8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918" },
          birth_date: { type: "string", format: "date", example: "1995-08-17" },
          gender: { type: "string", enum: ["Laki-laki", "Perempuan", "Lainnya"], example: "Laki-laki" },
          signup_method: { type: "string", enum: ["phone", "google", "apple"], example: "phone" },
          status: { type: "string", enum: ["active", "deactivated", "recycled"], default: "active" },
          is_profile_complete: { type: "boolean", default: true },
          medical_code: { type: "string", example: "KDT-A1B2C3D4E5F6" },
          email_verified: { type: "boolean", default: false },
          profile_photo_url: { type: "string", nullable: true },
          nik: { type: "string", example: "3578011708950001" },
          address: { type: "string", example: "Jl. Soekarno Hatta No. 45, Lowokwaru, Kota Malang" }
        }
      },

      ProfileUpdateRequest: {
        type: "object",
        properties: {
          full_name: { type: "string", example: "Budi Santoso, S.Kom" },
          email: { type: "string", format: "email", example: "budi.santoso.baru@gmail.com" },
          phone: { type: "string", example: "+6281299998888" },
          birth_date: { type: "string", format: "date", example: "1995-08-17" },
          gender: { type: "string", enum: ["Laki-laki", "Perempuan", "Lainnya"] },
          nik: { type: "string", example: "3578011708950001" },
          address: { type: "string", example: "Jl. Ijen No. 12, Malang" },
          profile_photo_url: { type: "string", nullable: true },
          email_verified: { type: "boolean" },
          is_profile_complete: { type: "boolean" },
          medical_code: { type: "string" },
          status: { type: "string", enum: ["active", "deactivated", "recycled"] },
          last_login_at: { type: "string", format: "date-time" },
          phone_changed_at: { type: "string", format: "date-time" },
          email_changed_at: { type: "string", format: "date-time" }
        }
      },

      // -----------------------------------------------------------------------
      // TABLE 2: APPOINTMENTS (39 COLUMNS)
      // -----------------------------------------------------------------------
      Appointment: {
        type: "object",
        description: "Skema lengkap baris tabel `public.appointments` (39 Kolom).",
        required: [
          "id",
          "booker_id",
          "patient_is_self",
          "service_type",
          "appointment_date",
          "appointment_time",
          "session_count",
          "appointment_status",
          "payment_plan",
          "payment_status",
          "base_price",
          "travel_fee",
          "discount_amount",
          "discount_percent",
          "total_amount",
          "amount_due",
          "created_at",
          "updated_at"
        ],
        properties: {
          id: {
            type: "string",
            format: "uuid",
            description: "Primary Key identitas unik janji temu",
            example: "8f1e582e-64d5-455b-9d41-789a12bc34de"
          },
          booker_id: {
            type: "string",
            format: "uuid",
            description: "ID user pemesan (relasi ke auth.users(id))",
            example: "550e8400-e29b-41d4-a716-446655440000"
          },
          patient_is_self: {
            type: "boolean",
            default: true,
            description: "True jika reservasi untuk diri sendiri, false jika untuk keluarga/orang lain",
            example: true
          },
          patient_nik: {
            type: "string",
            nullable: true,
            description: "NIK KTP pasien",
            example: "3578011708950001"
          },
          patient_medical_code: {
            type: "string",
            nullable: true,
            description: "Nomor rekam medis pasien",
            example: "KDT-A1B2C3D4E5F6"
          },
          patient_full_name: {
            type: "string",
            nullable: true,
            description: "Nama lengkap pasien penerima layanan terapi",
            example: "Budi Santoso"
          },
          patient_birth_date: {
            type: "string",
            format: "date",
            nullable: true,
            description: "Tanggal lahir pasien (YYYY-MM-DD)",
            example: "1995-08-17"
          },
          patient_phone: {
            type: "string",
            nullable: true,
            description: "Nomor telepon/WhatsApp pasien",
            example: "+6281234567890"
          },
          patient_gender: {
            type: "string",
            nullable: true,
            description: "Jenis kelamin pasien",
            example: "Laki-laki"
          },
          patient_complaint: {
            type: "string",
            nullable: true,
            description: "Keluhan utama / sakit yang dirasakan pasien",
            example: "Nyeri punggung bawah (LBP) setelah mengangkat beban berat"
          },
          service_type: {
            type: "string",
            enum: ["Klinik", "Home Care"],
            description: "Jenis layanan fisioterapi",
            example: "Klinik"
          },
          clinic_name: {
            type: "string",
            nullable: true,
            description: "Nama cabang klinik (jika service_type = Klinik)",
            example: "Klinik Kedota Malang Tunggulwulung"
          },
          address: {
            type: "string",
            nullable: true,
            description: "Alamat lengkap penanganan (jika service_type = Home Care)",
            example: "Jl. Soekarno Hatta No. 45, Malang"
          },
          therapist_name: {
            type: "string",
            nullable: true,
            description: "Nama fisioterapis yang menangani pasien",
            example: "Dimas Pratama, S.Fis"
          },
          therapist_gender_preference: {
            type: "string",
            nullable: true,
            description: "Preferensi gender terapis yang diminta pasien (Laki-laki / Perempuan / Bebas)",
            example: "Laki-laki"
          },
          therapist_availability_requested: {
            type: "string",
            nullable: true,
            description: "Catatan waktu ketersediaan terapis yang diminta",
            example: "Pagi hari"
          },
          appointment_date: {
            type: "string",
            format: "date",
            description: "Tanggal janji temu terapi (YYYY-MM-DD)",
            example: "2026-10-25"
          },
          appointment_time: {
            type: "string",
            format: "time",
            description: "Waktu jam janji temu terapi (HH:MM:SS)",
            example: "10:00:00"
          },
          session_count: {
            type: "integer",
            enum: [1, 3, 6, 9],
            default: 1,
            description: "Jumlah paket sesi penanganan",
            example: 1
          },
          appointment_status: {
            type: "string",
            enum: ["upcoming", "completed", "expired", "cancelled"],
            default: "upcoming",
            description: "Status jalannya janji temu",
            example: "upcoming"
          },
          payment_plan: {
            type: "string",
            enum: ["full", "deposit"],
            default: "full",
            description: "Rencana skema pembayaran: Full (bayar lunas di awal) atau Deposit (DP)",
            example: "full"
          },
          payment_method: {
            type: "string",
            nullable: true,
            description: "Metode transaksi pembayaran yang dipilih",
            example: "Transfer Bank BCA"
          },
          payment_status: {
            type: "string",
            enum: ["paid", "pending", "failed", "expired"],
            default: "pending",
            description: "Status pembayaran transaksi",
            example: "paid"
          },
          base_price: {
            type: "integer",
            format: "int64",
            default: 0,
            description: "Harga pokok layanan dalam Rupiah",
            example: 250000
          },
          travel_fee: {
            type: "integer",
            format: "int64",
            default: 0,
            description: "Ongkos biaya transport Home Care dalam Rupiah",
            example: 0
          },
          discount_amount: {
            type: "integer",
            format: "int64",
            default: 0,
            description: "Besaran potongan diskon dalam Rupiah",
            example: 25000
          },
          discount_code: {
            type: "string",
            nullable: true,
            description: "Kode voucher promo yang digunakan",
            example: "NEWCLINIC10"
          },
          discount_percent: {
            type: "integer",
            default: 0,
            minimum: 0,
            maximum: 100,
            description: "Persentase potongan promo",
            example: 10
          },
          total_amount: {
            type: "integer",
            format: "int64",
            default: 0,
            description: "Total nominal keseluruhan tagihan",
            example: 225000
          },
          amount_due: {
            type: "integer",
            format: "int64",
            default: 0,
            description: "Sisa tagihan yang belum dibayar",
            example: 0
          },
          booking_code: {
            type: "string",
            nullable: true,
            description: "Kode booking unik rekam medis (e.g. EMR-YYYYMMDD-XXXX)",
            example: "EMR-20261025-A7F9"
          },
          clinical_note: {
            type: "string",
            nullable: true,
            description: "Catatan diagnosa dan progres klinis pasca-terapi",
            example: "Pasien menunjukkan perbaikan mobilitas lumbal, spasme erector spinae berkurang."
          },
          vas_score: {
            type: "integer",
            nullable: true,
            minimum: 0,
            maximum: 10,
            description: "Skor nyeri Visual Analog Scale (0 = tidak nyeri, 10 = nyeri sangat hebat)",
            example: 3
          },
          rom_score: {
            type: "integer",
            nullable: true,
            description: "Skor derajat Range of Motion (kelenturan sendi)",
            example: 85
          },
          mmt_score: {
            type: "integer",
            nullable: true,
            description: "Skor Manual Muscle Testing (kekuatan otot, skala 0-5)",
            example: 4
          },
          odi_score: {
            type: "integer",
            nullable: true,
            minimum: 0,
            maximum: 50,
            description: "Skor disabilitas Oswestry Disability Index",
            example: 12
          },
          therapist_recommendation: {
            type: "string",
            nullable: true,
            description: "Instruksi dan rekomendasi latihan rumahan dari fisioterapis",
            example: "Lakukan peregangan hamstring dan knee-to-chest 2x sehari selama 10 menit."
          },
          therapist_sipf: {
            type: "string",
            nullable: true,
            description: "Nomor Surat Izin Praktik Fisioterapis (SIPF)",
            example: "SIPF.35.78.2023.00192"
          },
          therapist_photo_url: {
            type: "string",
            format: "uri",
            nullable: true,
            description: "Foto profil terapis",
            example: "https://wwmctqhbqpsbkyxkeaqv.supabase.co/storage/v1/object/public/therapists/dimas.jpg"
          },
          created_at: {
            type: "string",
            format: "date-time",
            description: "Waktu pembuatan record janji temu",
            example: "2026-10-20T11:00:00Z"
          },
          updated_at: {
            type: "string",
            format: "date-time",
            description: "Waktu update terakhir janji temu",
            example: "2026-10-20T11:00:00Z"
          }
        }
      },

      AppointmentInsertRequest: {
        type: "object",
        required: [
          "booker_id",
          "patient_is_self",
          "patient_full_name",
          "service_type",
          "appointment_date",
          "appointment_time",
          "session_count",
          "payment_plan",
          "payment_method",
          "base_price",
          "total_amount",
          "amount_due"
        ],
        properties: {
          booker_id: { type: "string", format: "uuid", example: "550e8400-e29b-41d4-a716-446655440000" },
          patient_is_self: { type: "boolean", default: true },
          patient_nik: { type: "string", example: "3578011708950001" },
          patient_medical_code: { type: "string", example: "KDT-A1B2C3D4E5F6" },
          patient_full_name: { type: "string", example: "Budi Santoso" },
          patient_birth_date: { type: "string", format: "date", example: "1995-08-17" },
          patient_phone: { type: "string", example: "+6281234567890" },
          patient_gender: { type: "string", example: "Laki-laki" },
          patient_complaint: { type: "string", example: "Nyeri leher tegang karena kerja komputer" },
          service_type: { type: "string", enum: ["Klinik", "Home Care"], example: "Klinik" },
          clinic_name: { type: "string", example: "Klinik Kedota Malang Tunggulwulung" },
          address: { type: "string", example: "Jl. Soekarno Hatta No. 45, Malang" },
          therapist_gender_preference: { type: "string", example: "Laki-laki" },
          therapist_availability_requested: { type: "string", example: "Pagi hari" },
          appointment_date: { type: "string", format: "date", example: "2026-10-25" },
          appointment_time: { type: "string", format: "time", example: "10:00:00" },
          session_count: { type: "integer", enum: [1, 3, 6, 9], default: 1 },
          payment_plan: { type: "string", enum: ["full", "deposit"], default: "full" },
          payment_method: { type: "string", example: "Transfer Bank BCA" },
          payment_status: { type: "string", enum: ["paid", "pending"], default: "paid" },
          appointment_status: { type: "string", default: "upcoming" },
          base_price: { type: "integer", format: "int64", example: 250000 },
          travel_fee: { type: "integer", format: "int64", example: 0 },
          discount_amount: { type: "integer", format: "int64", example: 25000 },
          discount_code: { type: "string", nullable: true, example: "NEWCLINIC10" },
          discount_percent: { type: "integer", example: 10 },
          total_amount: { type: "integer", format: "int64", example: 225000 },
          amount_due: { type: "integer", format: "int64", example: 0 }
        }
      },

      AppointmentUpdateRequest: {
        type: "object",
        properties: {
          appointment_status: {
            type: "string",
            enum: ["upcoming", "completed", "expired", "cancelled"],
            example: "cancelled"
          },
          booking_code: { type: "string", example: "EMR-20261025-A7F9" },
          clinical_note: { type: "string" },
          vas_score: { type: "integer", minimum: 0, maximum: 10 },
          rom_score: { type: "integer" },
          mmt_score: { type: "integer" },
          odi_score: { type: "integer", minimum: 0, maximum: 50 },
          therapist_recommendation: { type: "string" },
          therapist_sipf: { type: "string" },
          therapist_name: { type: "string" },
          therapist_photo_url: { type: "string" }
        }
      },

      // -----------------------------------------------------------------------
      // TABLE 3: ERROR_LOGS (8 COLUMNS)
      // -----------------------------------------------------------------------
      ErrorLog: {
        type: "object",
        description: "Skema lengkap baris tabel `public.error_logs` (8 Kolom).",
        required: ["id", "source", "method", "path", "status_code", "received_at"],
        properties: {
          id: {
            type: "integer",
            format: "int64",
            description: "Primary Key identity otomatis",
            example: 1042
          },
          source: {
            type: "string",
            description: "Sumber pengirim log error",
            example: "flutter_client"
          },
          method: {
            type: "string",
            description: "HTTP Method dari request yang gagal",
            example: "POST"
          },
          path: {
            type: "string",
            description: "Endpoint path yang menyebabkan server error",
            example: "/rest/v1/rpc/reschedule_appointment"
          },
          status_code: {
            type: "integer",
            minimum: 500,
            maximum: 599,
            description: "HTTP 5xx Server Error status code",
            example: 500
          },
          message: {
            type: "string",
            nullable: true,
            description: "Pesan detail exception / error",
            example: "PostgrestException: Appointment slot is unavailable"
          },
          platform: {
            type: "string",
            nullable: true,
            description: "Platform client",
            example: "android"
          },
          received_at: {
            type: "string",
            format: "date-time",
            description: "Timestamp waktu log diterima server",
            example: "2026-10-20T17:59:00Z"
          }
        }
      },

      ErrorLogInsertRequest: {
        type: "object",
        required: ["source", "method", "path", "status_code"],
        properties: {
          source: { type: "string", example: "flutter_client" },
          method: { type: "string", example: "POST" },
          path: { type: "string", example: "/rest/v1/appointments" },
          status_code: { type: "integer", minimum: 500, maximum: 599, example: 500 },
          message: { type: "string", example: "Internal database timeout" },
          platform: { type: "string", example: "android" }
        }
      },

      // -----------------------------------------------------------------------
      // AUTH & RPC SCHEMAS
      // -----------------------------------------------------------------------
      AuthPasswordLoginRequest: {
        type: "object",
        required: ["email", "password"],
        properties: {
          email: {
            type: "string",
            format: "email",
            description: "Email pengguna atau email identity telepon (e.g. 081234567890@kedota.local)",
            example: "081234567890@kedota.local"
          },
          password: {
            type: "string",
            description: "6-digit PIN keamanan akun",
            example: "123456"
          }
        }
      },

      AuthIdTokenLoginRequest: {
        type: "object",
        required: ["provider", "id_token"],
        properties: {
          provider: {
            type: "string",
            enum: ["google", "apple"],
            example: "google"
          },
          id_token: {
            type: "string",
            description: "OpenID Connect ID Token yang diperoleh dari Google Sign-In SDK",
            example: "eyJhbGciOiJSUzI1NiIs..."
          },
          access_token: {
            type: "string",
            nullable: true,
            description: "Google OAuth Access Token",
            example: "ya29.a0AfH6SM..."
          }
        }
      },

      AuthRefreshTokenRequest: {
        type: "object",
        required: ["refresh_token"],
        properties: {
          refresh_token: {
            type: "string",
            description: "Token refresh untuk memperbarui token sesi JWT",
            example: "d197df32-fa69-4f76-8809-548483b8d145"
          }
        }
      },

      AuthSignUpRequest: {
        type: "object",
        required: ["email", "password"],
        properties: {
          email: {
            type: "string",
            format: "email",
            example: "081234567890@kedota.local"
          },
          password: {
            type: "string",
            description: "6 digit PIN",
            example: "123456"
          },
          data: {
            type: "object",
            properties: {
              phone: { type: "string", example: "+6281234567890" },
              full_name: { type: "string", example: "Budi Santoso" },
              signup_method: { type: "string", example: "phone" }
            }
          }
        }
      },

      SendOtpRequest: {
        type: "object",
        properties: {
          phone: {
            type: "string",
            description: "Nomor telepon tujuan SMS/WhatsApp OTP",
            example: "+6281234567890"
          },
          email: {
            type: "string",
            format: "email",
            description: "Alamat email tujuan OTP",
            example: "budi@example.com"
          },
          channel: {
            type: "string",
            enum: ["sms", "whatsapp"],
            default: "sms"
          },
          shouldCreateUser: {
            type: "boolean",
            default: false
          }
        }
      },

      VerifyOtpRequest: {
        type: "object",
        required: ["token", "type"],
        properties: {
          token: {
            type: "string",
            description: "6 digit kode OTP",
            example: "123456"
          },
          type: {
            type: "string",
            enum: ["sms", "email", "recovery", "phone_change", "email_change"],
            example: "sms"
          },
          phone: {
            type: "string",
            example: "+6281234567890"
          },
          email: {
            type: "string",
            format: "email",
            example: "budi@example.com"
          }
        }
      },

      AuthSessionResponse: {
        type: "object",
        properties: {
          access_token: {
            type: "string",
            description: "Bearer JWT access token untuk otentikasi request berikutnya",
            example: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
          },
          token_type: { type: "string", example: "bearer" },
          expires_in: { type: "integer", example: 3600 },
          refresh_token: {
            type: "string",
            example: "d197df32-fa69-4f76-8809-548483b8d145"
          },
          user: {
            $ref: "#/components/schemas/AuthUser"
          }
        }
      },

      AuthUser: {
        type: "object",
        properties: {
          id: { type: "string", format: "uuid", example: "550e8400-e29b-41d4-a716-446655440000" },
          email: { type: "string", format: "email", example: "081234567890@kedota.local" },
          phone: { type: "string", example: "+6281234567890" },
          created_at: { type: "string", format: "date-time" },
          user_metadata: {
            type: "object",
            properties: {
              full_name: { type: "string", example: "Budi Santoso" },
              signup_method: { type: "string", example: "phone" }
            }
          }
        }
      },

      RescheduleRpcRequest: {
        type: "object",
        required: ["p_appointment_id", "p_appointment_date", "p_appointment_time"],
        properties: {
          p_appointment_id: {
            type: "string",
            format: "uuid",
            description: "UUID appointment yang ingin dijadwalkan ulang",
            example: "8f1e582e-64d5-455b-9d41-789a12bc34de"
          },
          p_appointment_date: {
            type: "string",
            format: "date",
            description: "Tanggal baru yang dipilih (YYYY-MM-DD)",
            example: "2026-10-28"
          },
          p_appointment_time: {
            type: "string",
            format: "time",
            description: "Jam baru yang dipilih (HH:MM:SS)",
            example: "14:00:00"
          }
        }
      },

      SettlePaymentRpcRequest: {
        type: "object",
        required: ["p_appointment_id", "p_payment_method"],
        properties: {
          p_appointment_id: {
            type: "string",
            format: "uuid",
            description: "UUID appointment yang ingin dilunasi tagihannya",
            example: "8f1e582e-64d5-455b-9d41-789a12bc34de"
          },
          p_payment_method: {
            type: "string",
            description: "Metode pembayaran pelunasan (e.g. 'Transfer Bank BCA', 'QRIS', 'Tunai')",
            example: "QRIS"
          }
        }
      },

      RestCryptoEnvelope: {
        type: "object",
        description: "Envelope payload terenkripsi client-to-server (AES-GCM + HMAC)",
        required: ["data", "iv", "sig"],
        properties: {
          data: {
            type: "string",
            description: "Ciphertext base64 dari data JSON { profile_id, new_pin_hash, new_pin }",
            example: "VGVzdEVuY3J5cHRpb25EYXRh..."
          },
          iv: {
            type: "string",
            description: "Initialization Vector base64 untuk AES-GCM",
            example: "aXZFeGFtcGxlMTI="
          },
          sig: {
            type: "string",
            description: "HMAC-SHA256 signature dari ciphertext untuk integritas data",
            example: "c2lnbmF0dXJlRXhhbXBsZQ=="
          }
        }
      },

      ClientErrorLogRequest: {
        type: "object",
        required: ["source", "method", "path", "status_code"],
        properties: {
          source: { type: "string", default: "flutter_client", example: "flutter_client" },
          method: { type: "string", example: "GET" },
          path: { type: "string", example: "/rest/v1/appointments" },
          status_code: { type: "integer", minimum: 500, maximum: 599, example: 502 },
          message: { type: "string", example: "Bad gateway from upstream database" },
          platform: { type: "string", example: "android" }
        }
      },

      ErrorResponse: {
        type: "object",
        properties: {
          code: { type: "string", example: "23505" },
          message: { type: "string", example: "Appointment slot is unavailable" },
          details: { type: "string", nullable: true },
          hint: { type: "string", nullable: true }
        }
      }
    }
  }
};

// 1. Write swagger.json
const jsonPath = path.join(__dirname, 'swagger.json');
fs.writeFileSync(jsonPath, JSON.stringify(openApiSpec, null, 2), 'utf-8');
console.log(`Successfully generated ${jsonPath}`);

// 2. Write swagger.yaml using standard YAML stringify
const yamlPath = path.join(__dirname, 'swagger.yaml');
const yamlDoc = new YAML.Document(openApiSpec);
fs.writeFileSync(yamlPath, yamlDoc.toString(), 'utf-8');
console.log(`Successfully generated ${yamlPath}`);

// 3. Write interactive swagger-ui.html
const htmlPath = path.join(__dirname, 'swagger-ui.html');
const htmlContent = `<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <title>Kedota Physiotherapy - Swagger API Docs</title>
  <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui.css" />
  <link rel="icon" type="image/png" href="https://unpkg.com/swagger-ui-dist@5.11.0/favicon-32x32.png" sizes="32x32" />
  <style>
    html { box-sizing: border-box; overflow: -moz-scrollbars-vertical; overflow-y: scroll; }
    *, *:before, *:after { box-sizing: inherit; }
    body { margin: 0; background: #fafafa; font-family: sans-serif; }
    .top-header {
      background: #007F78;
      color: white;
      padding: 16px 24px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      box-shadow: 0 2px 8px rgba(0,0,0,0.15);
    }
    .top-header h1 { margin: 0; font-size: 20px; font-weight: 600; }
    .top-header p { margin: 4px 0 0; font-size: 13px; opacity: 0.9; }
    .badge {
      background: #00A79D;
      padding: 6px 12px;
      border-radius: 16px;
      font-size: 12px;
      font-weight: 600;
    }
    #swagger-ui { max-width: 1280px; margin: 0 auto; padding: 20px; }
  </style>
</head>
<body>
  <div class="top-header">
    <div>
      <h1>Kedota Physiotherapy App - API Specification</h1>
      <p>Dokumentasi Swagger Lengkap: Semua Screen, GET/POST/PATCH/DELETE, dan Seluruh Kolom Database</p>
    </div>
    <div class="badge">OpenAPI 3.0.3</div>
  </div>
  <div id="swagger-ui"></div>
  <script src="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui-bundle.js"></script>
  <script src="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui-standalone-preset.js"></script>
  <script>
    window.onload = function() {
      const spec = ${JSON.stringify(openApiSpec)};
      window.ui = SwaggerUIBundle({
        spec: spec,
        dom_id: '#swagger-ui',
        deepLinking: true,
        presets: [
          SwaggerUIBundle.presets.apis,
          SwaggerUIStandalonePreset
        ],
        plugins: [
          SwaggerUIBundle.plugins.DownloadUrl
        ],
        layout: "BaseLayout",
        defaultModelsExpandDepth: 2,
        defaultModelExpandDepth: 2,
        docExpansion: "list"
      });
    };
  </script>
</body>
</html>
`;

fs.writeFileSync(htmlPath, htmlContent, 'utf-8');
console.log(`Successfully generated ${htmlPath}`);
