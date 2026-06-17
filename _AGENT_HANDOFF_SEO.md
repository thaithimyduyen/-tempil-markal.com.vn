# BÀN GIAO CÔNG VIỆC SEO — markal.com.vn

> **Mục đích:** Tài liệu này tóm tắt toàn bộ thay đổi đã thực hiện trên site `markal.com.vn` để một agent/người khác có thể tiếp tục chính xác.
> **Cập nhật lần cuối:** 2026-06-17
> **Site:** Static HTML/SSG, deploy qua GitHub Pages (CNAME = `markal.com.vn`). Không có build step — sửa HTML trực tiếp.
> **Chủ site:** Fast Group Engineering (phân phối chính hãng Markal, Tempil, LA-CO tại Việt Nam).

---

## 0. QUY TẮC VẬN HÀNH QUAN TRỌNG (đọc trước khi sửa)

| # | Lưu ý | Chi tiết |
|---|-------|----------|
| 1 | **Deploy** | Site là GitHub Pages. Mọi thay đổi chỉ lên live sau khi `git add . && git commit && git push`. |
| 2 | **Xem local** | Phải chạy qua **Live Server** (vd `http://127.0.0.1:5500/`). KHÔNG mở bằng `file://` (link & ảnh dùng đường dẫn tuyệt đối `/shop/`, `/assets/`). Sau khi sửa, hard-refresh **Ctrl+Shift+R** để bỏ cache. |
| 3 | **⚠️ Cảnh báo resync** | Trong quá trình làm, có lần file đã sửa **bị một tiến trình sync ghi đè/khôi phục** (thư mục từng có `_backup_sync_*`). Sau khi sửa hàng loạt, PHẢI verify lại và kiểm tra xem có script auto-sync nào đang chạy ghi đè thư mục web không. |
| 4 | **Xóa file** | Thư mục cowork chặn `rm`. Nếu cần xóa, dùng cơ chế cấp quyền xóa của Cowork (`allow_cowork_file_delete`) rồi mới `rm`. |
| 5 | **Sửa hàng loạt** | Luôn backup file trước khi sửa; sửa bằng script Python (regex), verify ngay sau đó (đếm, parse JSON-LD, check link/ảnh). |

---

## 1. NGUỒN DỮ LIỆU

| Nguồn | Vai trò |
|-------|---------|
| `shop/search-index.json` | Index gốc: `{pn, name(EN), url}` cho ~753 SKU. |
| `shop/pn-index.json` | Map `part number → url` (cả dạng có/không số 0 đầu). Dùng để link PN. |
| `shop/catalog-index.json` | **Index chính đã làm giàu** (xem schema mục 4). Nguồn render trang Shop. |
| `MASTER_Price_List.xlsx` (user upload) | Bảng giá gốc LA-CO/Markal/Tempil: cột `Part No., Brand, Product Line, Product Name/Description(EN), ...`. Tên EN + **nhiệt độ Tempilstik** nằm trong cột mô tả. ~697 dòng. **Lưu ý: file này KHÔNG nằm trong repo** — user upload qua phiên chat. Nếu cần lại, xin user gửi lại. |

---

## 2. CÁC VIỆC ĐÃ HOÀN THÀNH (theo nhóm)

### A. Dọn dẹp & sửa lỗi SEO nền tảng
- **Gỡ schema `"price":"0"`** không hợp lệ khỏi **753** trang `/shop/*/`. Mô hình B2B là báo giá → đã xóa hẳn block `offers` khỏi Product JSON-LD (hết cảnh báo Google). *(Lưu ý: lần đầu bị resync ghi đè, đã làm lại — cần kiểm tra giữ ổn định.)*
- **Xóa rác:** thư mục `_backup_sync_20260616-065022/`, file `-tempil-markal.com.vn.zip` (10MB lộ source), 2 file template leak `products.html` + `product_detail.html` (chứa `{{meta_title}}`, `{{image}}`...).
- **Sửa lỗi ligature `ﬁ` (U+FB01) & chuỗi literal `#Ufb01`:** xuất hiện trong tên thư mục, canonical, link nội bộ và tên ảnh → chuẩn hóa hết về `fi`.
  - Đổi tên 3 thư mục: `markal_pro_re#Ufb01lls`→`markal_pro_refills`, `markal_pro_welding_re#Ufb01lls`→`markal_pro_welding_refills`, `tempil/certi#Ufb01ed_thermomelt`→`tempil/certified_thermomelt`.
  - Xóa 1 thư mục trùng lặp `markal/paint_riter_certi#Ufb01ed` (bản cũ, giữ `paint_riter_certified`).
  - Khôi phục 5 ảnh `.webp` về tên ASCII đúng.
- **Sửa ảnh hỏng:** repoint 12 ảnh `..._1.webp` (sai separator) sang biến thể có thật → **0 ảnh local 404**.
- **Sửa link chết:** `/tempil/heat_stik/` → `/markal/heat_stik/` trong 1 bài blog.
- **Sitemap:** bổ sung 9 URL thiếu → **921 URL = đủ 100% trang**, XML hợp lệ. `robots.txt` đã đúng (có Sitemap, Disallow `/assets/data/`).

### B. Trang Shop `/shop/index.html` (đã dựng lại nhiều lần)
- Trước đây chỉ có ô tìm kiếm + vài card "duyệt theo thương hiệu". Nay là **catalog đầy đủ 753 sản phẩm**, render **tĩnh trong HTML** (không phụ thuộc fetch/JS — tốt cho SEO & hiển thị chắc chắn).
- **Đồng bộ giao diện toàn site:** dùng chung `/assets/style.css` + `/assets/js/app.js` (hamburger toggle dùng class `is-open`/`is-active`), markup sidebar + footer 4 cột **giống hệt** các trang `/markal`, `/tempil`. Sidebar có thêm mục **Shop** (active).
- **Nội dung dày:** đoạn intro, dải tin cậy (trust strip), mô tả từng nhóm, **FAQ có schema `FAQPage`**, CTA báo giá.
- Mỗi card hiển thị: **ảnh sản phẩm** (lazy-load) + **tên tiếng Việt** (đậm) + **tên tiếng Anh** (nghiêng) + Mã PN + **badge nhiệt độ** 🌡 (nếu có).
- **KHÔNG liệt kê số lượng mã hàng** (theo yêu cầu user) — đã bỏ mọi "N mã", số đếm trên nav/nhóm.
- Ô tìm kiếm là **tùy chọn**, lọc tại chỗ theo `data-s` (tên VI + EN + nhiệt độ + PN). Gõ đúng PN → nhảy thẳng trang sản phẩm.
- 22 category jump-nav chips (sticky).

### C. Liên kết Part Number (trang nhóm → shop)
- Quét toàn bộ trang nhóm `/markal/*`, `/tempil/*`, `/laco/*`. Thêm **338 link** từ ô part number trong bảng (`<td class="part-no">PN</td>`, `<td>PN</td>`) → trang `/shop/SKU/` tương ứng (qua `pn-index.json`). 63 trang được sửa.
- 20 ô PN không có trang shop tương ứng → để nguyên (không có đích).

### D. Song ngữ EN/VI + nhiệt độ (từ Excel)
- Khớp PN giữa catalog (753) và Excel (690 khớp, 63 fallback dùng tên sẵn có).
- Thêm vào `catalog-index.json` mỗi item: `en` (tên Anh), `vi` (tên Việt), `temp` (nhiệt độ làm việc), `s` (chuỗi search gộp).
- **Nhiệt độ:** parse từ mô tả Excel, xử lý 3 định dạng: `X°F (Y°C)`, chỉ `°C` (tự quy đổi ra °F), chỉ `°F`. **253 mã** có nhiệt độ.

### E. SEO trang sản phẩm nhiệt độ (250 trang) + đa dạng hóa từ khóa
- **Vấn đề gốc:** gần như mọi trang Tempilstik có **title trùng nhau** ("Tempilstik- Temperature Indicating Stick – Mã XXX"), không có nhiệt độ → trùng lặp, không rank.
- Đã cập nhật `<title>`, `<h1>`, `meta description`, `og:title/description`, `twitter:title/description`, và `Product.name` (schema) cho **250 trang** kiểm tra nhiệt → mỗi trang **title duy nhất** có tên VI + model EN + nhiệt độ + mã.
- **Đa dạng hóa từ khóa** (theo yêu cầu user): gán biến thể luân phiên cố định theo mã để chiếm nhiều cụm tìm kiếm:
  - Bút: *Bút kiểm tra nhiệt độ / Bút thử nhiệt độ / Bút đo nhiệt độ / Bút kiểm tra nhiệt / Que thử nhiệt độ / Bút chỉ thị nhiệt độ*
  - Nhãn: *Nhãn kiểm tra / đo / chỉ thị / thử nhiệt độ / Tem kiểm tra nhiệt độ*
  - Dung dịch: *Dung dịch / Sơn kiểm tra / đo / chỉ thị / thử nhiệt độ*
- **Chuyển nhóm:** 22 mã Thermomelt bị phân nhóm sai ("Metal Markers" trên site gốc) → đã chuyển sang nhóm **temp-sticks** trong `catalog-index.json` (nhận diện theo tên VI, không theo nhóm sai). temp-sticks=138, metal-markers=310.

---

## 3. TRẠNG THÁI HIỆN TẠI (số liệu xác nhận)

| Chỉ số | Giá trị |
|--------|---------|
| Tổng trang (index.html + contact.html) | 921 |
| URL trong sitemap | 921 (khớp 100%) |
| Sản phẩm trong catalog-index.json | 753 (22 nhóm) |
| Mã có nhiệt độ | 253 |
| Trang sản phẩm nhiệt độ đã tối ưu title/H1 | 250 (title 100% unique) |
| Ảnh local hỏng | 0 |
| Schema `price:"0"` còn lại | 0 |
| Lỗi ligature `ﬁ`/`#Ufb01` còn lại | 0 |
| Link nội bộ chết | 0 |

---

## 4. SCHEMA `shop/catalog-index.json`

```jsonc
[
  {
    "id": "temp-sticks",                       // id nhóm (dùng làm anchor #id)
    "label": "Bút kiểm tra nhiệt (Temperature Indicating Sticks)",
    "count": 138,
    "items": [
      {
        "pn": "028000",                        // part number (6 chữ số, có 0 đầu)
        "name": "Tempilstik- Temperature...",  // tên gốc từ search-index (legacy)
        "url": "/shop/but-kiem-tra-nhiet-tempilstik-028000/",
        "img": "/shop/.../img/xxx.webp",       // ảnh đại diện
        "en": "Tempilstik 100°F (38°C)",       // tên tiếng Anh (từ Excel, đã làm sạch)
        "vi": "Bút kiểm tra nhiệt độ 100°F (38°C)", // tên tiếng Việt (đã gán biến thể từ khóa)
        "temp": "100°F (38°C)",                // nhiệt độ làm việc (rỗng nếu không có)
        "vtype": "Bút kiểm tra nhiệt độ",       // biến thể từ khóa đã chọn (chỉ item nhiệt độ)
        "s": "bút kiểm tra nhiệt độ 100°f ..."  // chuỗi search gộp (lowercase)
      }
    ]
  }
]
```

**QUAN TRỌNG về quy trình render:** Trang `shop/index.html` được **sinh ra từ `catalog-index.json`** bằng script Python (đã xoá sau khi chạy). Trang sản phẩm `/shop/SKU/` cũng đọc biến thể từ `catalog-index.json`. → **Nếu sửa dữ liệu, sửa trong `catalog-index.json` rồi render lại**, đừng sửa tay 753 card trong HTML.

---

## 5. CÁCH TÁI TẠO SCRIPT (đã xoá sau khi chạy)

Các script generator đã xoá để giữ thư mục sạch. Logic để dựng lại:

1. **Render trang Shop** (`shop/index.html`): đọc `catalog-index.json`, với mỗi nhóm sinh `<section class="catsec" id="{id}">` chứa các card `<a class="rcard" data-pn data-s>` gồm ảnh + badge temp + `rcard__vi` + `rcard__en` + `rcard__pn`. Dùng markup sidebar/footer chuẩn (copy từ `markal/index.html` dòng ~109–153 sidebar, ~2113–2199 footer) + `/assets/style.css` + `/assets/js/app.js`. Search lọc theo `data-s` trên DOM (không fetch). Thêm 3 JSON-LD: BreadcrumbList, CollectionPage, FAQPage. **Không in số đếm.**
2. **Cập nhật trang sản phẩm nhiệt độ:** với mỗi item có `temp` + `vtype`, đặt `title_name = vtype + " " + en`; thay `<title>`, `<h1 class="brand-title">`, meta description (mẫu: *"{title_name}, mã {pn}. {vtype} Markal – {verb} {temp}; dùng kiểm soát nhiệt tiền nhiệt và giữa các lớp hàn theo AWS, ASME..."*), og/twitter title+description, và `"@type": "Product", "name"` = `"{en} (Markal {pn})"`. Backup mỗi file trước khi sửa (guard không ghi đè backup gốc).

---

## 6. VIỆC NÊN LÀM TIẾP (ưu tiên cao → thấp)

1. **GA4 + Google Search Console** — site CHƯA có analytics (chỉ có `BingSiteAuth.xml`). Bắt buộc để đo SEO. Submit sitemap trong GSC.
2. **Local SEO** — tạo Google Business Profile cho 2 địa chỉ (HCM + Vũng Tàu), thêm schema `LocalBusiness` (NAP đồng nhất). Khách O&G/EPC tìm "đại lý Markal HCM".
3. **Áp song ngữ EN/VI cho ~500 trang sản phẩm KHÔNG nhiệt độ** (hiện mới làm phần nhiệt độ). Dùng `en`/`vi` đã có trong `catalog-index.json`.
4. **Tách bạch `/markal/` (hub) vs `/shop/` (SKU)** để tránh keyword cannibalization. Thêm link "Shop" vào sidebar các trang còn lại (`/`, `/markal`, `/tempil`, `/laco`) cho đồng nhất — HIỆN MỚI thêm ở trang Shop.
5. **Sửa "Nhóm sản phẩm" sai trên trang sản phẩm** của 22 Thermomelt (vẫn ghi "Metal Markers" trong spec-card dù đã chuyển nhóm ở catalog).
6. **Core Web Vitals** — đang nạp full Bootstrap + FontAwesome + 2 Google Fonts; cân nhắc purge CSS, self-host font, subset icon.

---

## 7. BACKUP

Backup trong phiên được lưu ở thư mục outputs của session (`markal_backup_*`) — **thư mục này có thể bị xoá giữa các phiên**, KHÔNG đáng tin lâu dài. Khuyến nghị mạnh: **đưa toàn bộ repo vào Git** và commit thường xuyên để có lịch sử khôi phục thật sự.

---
*Hết tài liệu bàn giao.*
