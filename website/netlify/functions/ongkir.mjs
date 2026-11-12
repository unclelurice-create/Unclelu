// Netlify Function: hitung ongkir antar Uncle Lu berdasarkan jarak
// Memakai OpenStreetMap: Nominatim (alamat -> koordinat) + OSRM (jarak rute). Tanpa API key.
// Opsional: environment variable ORIGIN_LATLNG (contoh "-6.2189,106.8309") agar titik toko presisi.

const ORIGIN_ADDRESSES = [
  "Jl. Sidik Gg. Tiong Ujung, Karet Kuningan, Setiabudi, Jakarta Selatan",
  "Jl. Sidik, Karet Kuningan, Setiabudi, Jakarta Selatan",
  "Karet Kuningan, Setiabudi, Jakarta Selatan",
];
const TARIF_PER_KM = 2500;
const ONGKIR_MIN = 12500;
const MAX_KM = 20;
const FAKTOR_GARIS_LURUS = 1.35; // dipakai hanya jika server rute OSRM sedang mati
const UA = { "User-Agent": "UncleLuOngkir/1.0 (website pre-order Uncle Lu)" };

const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" },
  });
const fail = (pesan, status = 200) => json({ ok: false, pesan }, status);

async function nominatim(q) {
  const url =
    "https://nominatim.openstreetmap.org/search" +
    `?q=${encodeURIComponent(q)}&format=jsonv2&limit=1&countrycodes=id` +
    "&viewbox=106.60,-5.90,107.10,-6.50&bounded=1";
  const r = await fetch(url, { headers: UA, signal: AbortSignal.timeout(8000) });
  if (!r.ok) throw new Error("nominatim " + r.status);
  const d = await r.json();
  if (!d.length) return null;
  return { lat: parseFloat(d[0].lat), lng: parseFloat(d[0].lon), terbaca: d[0].display_name };
}

async function geocodeAlamat(alamat) {
  const kandidat = [alamat];
  if (!/jakarta/i.test(alamat)) kandidat.push(alamat + ", Jakarta");
  for (const q of kandidat) {
    const hasil = await nominatim(q);
    if (hasil) return hasil;
  }
  return null;
}

let originCache = null;
async function getOrigin() {
  if (originCache) return originCache;
  const ll = Netlify.env.get("ORIGIN_LATLNG");
  if (ll) {
    const [lat, lng] = ll.split(",").map((s) => parseFloat(s.trim()));
    if (Number.isFinite(lat) && Number.isFinite(lng)) return (originCache = { lat, lng });
  }
  for (const a of ORIGIN_ADDRESSES) {
    const h = await nominatim(a);
    if (h) return (originCache = { lat: h.lat, lng: h.lng });
    await new Promise((r) => setTimeout(r, 1100)); // batas Nominatim: 1 permintaan/detik
  }
  return null;
}

function garisLurusKm(a, b) {
  const R = 6371, rad = (x) => (x * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat), dLng = rad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

async function jarakRuteKm(a, b) {
  try {
    const url = `https://router.project-osrm.org/route/v1/driving/${a.lng},${a.lat};${b.lng},${b.lat}?overview=false`;
    const r = await fetch(url, { headers: UA, signal: AbortSignal.timeout(8000) });
    if (r.ok) {
      const d = await r.json();
      if (d.code === "Ok" && d.routes?.length) return d.routes[0].distance / 1000;
    }
  } catch (e) {
    console.error("OSRM error:", e.message);
  }
  return garisLurusKm(a, b) * FAKTOR_GARIS_LURUS;
}

export default async (req) => {
  if (req.method !== "POST") return fail("Metode tidak diizinkan.", 405);

  let body;
  try {
    body = await req.json();
  } catch {
    return fail("Permintaan tidak valid.", 400);
  }

  let tujuan, terbaca = "";
  try {
    if (Number.isFinite(body.lat) && Number.isFinite(body.lng)) {
      if (body.lat < -11.5 || body.lat > 6.5 || body.lng < 94.5 || body.lng > 141.5) {
        return fail("Lokasi di luar wilayah layanan.");
      }
      tujuan = { lat: body.lat, lng: body.lng };
    } else if (typeof body.alamat === "string") {
      const alamat = body.alamat.trim().slice(0, 250);
      if (alamat.length < 5) return fail("Alamat terlalu pendek.");
      const g = await geocodeAlamat(alamat);
      if (!g) {
        return fail("Alamat tidak ditemukan di peta. Coba tulis nama jalan dan kelurahan saja, atau pakai tombol lokasi saya.");
      }
      tujuan = { lat: g.lat, lng: g.lng };
      terbaca = g.terbaca;
    } else {
      return fail("Isi alamat atau gunakan lokasi GPS.", 400);
    }

    const asal = await getOrigin();
    if (!asal) return fail("Titik toko belum bisa ditentukan. Hubungi penjual via WhatsApp.");

    const km = await jarakRuteKm(asal, tujuan);
    const jarak_km = Math.round(km * 10) / 10;

    if (jarak_km > MAX_KM) {
      return json({
        ok: false,
        jarak_km,
        pesan: `Maaf, jarak ${jarak_km} km di luar jangkauan antar (maks. ${MAX_KM} km). Silakan pilih Ambil sendiri.`,
      });
    }

    // jarak dibulatkan ke atas ke km bulat; kelipatan Rp2.500 sudah rapi (12.500, 15.000, 17.500, ...)
    const ongkir = Math.max(ONGKIR_MIN, Math.ceil(jarak_km) * TARIF_PER_KM);
    return json({ ok: true, jarak_km, ongkir, alamat_terbaca: terbaca });
  } catch (e) {
    console.error("ongkir error:", e);
    return fail("Layanan peta sedang sibuk. Coba lagi sebentar atau hubungi penjual.");
  }
};

export const config = { path: "/api/ongkir", method: "POST" };
