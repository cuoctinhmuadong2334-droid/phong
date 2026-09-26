# Phong Media — Portfolio quay & dựng video

Website portfolio tối giản, phong cách điện ảnh. Làm bằng [Astro](https://astro.build) + [Tailwind CSS](https://tailwindcss.com), host miễn phí trên [Vercel](https://vercel.com).

## Chạy thử trên máy

Cần cài [Node.js](https://nodejs.org) bản 20 trở lên.

```bash
npm install      # cài lần đầu
npm run dev      # mở http://localhost:4321, sửa file là trang tự cập nhật
npm run build    # kiểm tra trước khi đưa lên mạng
```

## Sửa nội dung (không cần biết code)

| Muốn sửa | File |
|---|---|
| Tên, slogan, SĐT/Zalo, Facebook/Instagram/TikTok, giới thiệu, dịch vụ, showreel | `src/data/site.ts` |
| Dự án | `src/content/projects/*.md` (mỗi dự án một file) |
| Ảnh (chân dung, thumbnail, video nền) | bỏ vào thư mục `public/` |
| Ảnh hiện khi share link lên Zalo/Facebook | `public/og.jpg` (1200×630) |

Những chỗ ghi **MẪU** là nội dung tạm, cần thay.

### Thêm một dự án

Tạo file mới, ví dụ `src/content/projects/tvc-cafe-x.md` (tên file = đường link `/du-an/tvc-cafe-x/`):

```md
---
title: "TVC Cà phê X"
client: "Cà phê X"
year: 2026
category: "TVC"          # TVC | MV | Sự kiện | Phim cưới | Mạng xã hội | Phim ngắn
role: "Quay, dựng, chỉnh màu"
youtubeId: "ABC123xyz"   # từ link https://youtu.be/ABC123xyz
featured: true           # true = đưa lên đầu
order: 10                # số lớn hiện trước
# thumbnail: "/thumbs/cafe-x.jpg"   # tùy chọn, mặc định lấy ảnh từ YouTube
# preview: "/thumbs/cafe-x.mp4"     # tùy chọn, clip 3–5s phát khi rê chuột
---

Mô tả dự án: ý tưởng, bạn đã làm gì, kết quả.
```

Muốn thêm thể loại mới: sửa danh sách `category` trong `src/content.config.ts`.

## Đưa video từ Google Drive lên YouTube

1. Tải video từ Drive về máy.
2. Vào [studio.youtube.com](https://studio.youtube.com) → **Tạo** → **Tải video lên**.
3. Ở bước "Chế độ hiển thị" chọn **Không công khai** (chỉ ai có link mới xem được — vẫn nhúng lên web được).
4. Copy link, phần sau `youtu.be/` là `youtubeId`.

## Video nền đầu trang (tùy chọn)

Chọn một đoạn đẹp 10–15 giây, nén nhỏ (dưới ~4MB) bằng [ffmpeg](https://ffmpeg.org):

```bash
ffmpeg -i goc.mp4 -t 15 -an -vf "scale=1920:-2,fps=25" -c:v libx264 -crf 28 -preset slow -movflags +faststart public/hero.mp4
ffmpeg -i public/hero.mp4 -frames:v 1 -q:v 3 public/hero.jpg
```

Rồi trong `src/data/site.ts` đặt `heroVideo: '/hero.mp4'` và `heroPoster: '/hero.jpg'`.

## Đưa lên mạng miễn phí (Vercel)

1. Vào [vercel.com](https://vercel.com) → **Sign up** bằng tài khoản GitHub.
2. **Add New… → Project** → chọn repo `phong` → **Import**.
3. Vercel tự nhận ra Astro → bấm **Deploy**. Khoảng 1 phút là có link `ten.vercel.app`.
4. Mở `astro.config.mjs`, sửa dòng `site:` thành link vừa có (để ảnh share và sitemap đúng).
5. Từ giờ mỗi lần push lên GitHub, Vercel tự cập nhật website.

Sau này mua domain riêng: Vercel → Project → **Settings → Domains** → thêm domain và làm theo hướng dẫn trỏ DNS.

## Tham khảo thiết kế

- Portfolio video: [Colorlib – filmmaker](https://colorlib.com/wp/filmmaker-website-examples/), [SiteBuilderReport – videography](https://www.sitebuilderreport.com/inspiration/videography-website-examples), [Format – video](https://www.format.com/online-portfolio-website/video/best)
- Cảm hứng web: [Awwwards](https://www.awwwards.com/websites/portfolio/), [Godly](https://godly.website), [Siteinspire](https://www.siteinspire.com), [Land-book](https://land-book.com), [Muzli](https://muz.li/blog/top-100-most-creative-and-unique-portfolio-websites-of-2025/)
- Hiệu ứng & template: [Codrops](https://tympanus.net/codrops/), [Astro Themes](https://astro.build/themes/)
