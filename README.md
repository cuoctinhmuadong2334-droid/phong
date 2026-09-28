# phong
luật của phong

Dự án video bằng [Remotion](https://www.remotion.dev/) (React + TypeScript).

## Cài đặt

```bash
npm install
```

## Lệnh

| Lệnh | Mô tả |
|------|-------|
| `npm run dev` | Mở Remotion Studio để xem/chỉnh video |
| `npm run build` | Render `HelloWorld` ra `out/video.mp4` |
| `npm run build:jersey` | Render video giới thiệu áo ra `out/jersey.mp4` |
| `npm run build:chalpha` | Render video dọc CH-Alpha Plus ra `out/chalpha.mp4` |
| `npm run build:chalpha-stats` | Render video dọc CH-Alpha Plus bản số liệu ra `out/chalpha-stats.mp4` |
| `npm run lint` | Kiểm tra TypeScript |
| `npm run upgrade` | Nâng cấp Remotion |

## Cấu trúc

- `src/index.ts` – điểm vào, đăng ký root
- `src/Root.tsx` – khai báo các composition (kích thước, fps, thời lượng)
- `src/HelloWorld.tsx` – component video mẫu
- `src/jersey/` – video giới thiệu áo thi đấu (1080×1080, ~9,5 giây)
  - `types.ts` – danh sách mẫu áo (tên, màu, nhãn màu) — sửa ở đây để đổi/thêm mẫu
  - `Shirt.tsx` – vẽ áo mặt trước/sau bằng SVG
  - `Badge.tsx`, `Logos.tsx` – huy hiệu và logo dạng chữ/hình đơn giản
- `src/chalpha/` – video quảng cáo dọc 9:16 CH-Alpha Plus (1080×1920, ~15 giây)
  - `content.ts` – toàn bộ chữ trên video (tiêu đề, công dụng, CTA, dòng lưu ý) và màu
  - `Joint.tsx` – minh họa khớp gối: sụn mòn → sụn phục hồi, hạt collagen, vùng viêm
  - `Scenes.tsx` – 4 cảnh: mở đầu, giới thiệu sản phẩm, công dụng, kêu gọi mua
  - `StatsPromo.tsx` – bản thứ hai: ống thuốc tách nền (`public/chalpha/ampoule.png`) + số liệu 42% / 45% / 88% chuyển động
- `public/chalpha/product.png` – ảnh sản phẩm đã tách nền
- `public/fonts/` – font đóng gói sẵn (SIL OFL) để render không cần mạng
- `remotion.config.ts` – cấu hình render

## GitHub Actions

Workflow `.github/workflows/render-video.yml` tự render video khi push lên `main`
(hoặc chạy tay qua tab **Actions → Render video → Run workflow**).
File MP4 được tải về trong mục **Artifacts** của lần chạy.
