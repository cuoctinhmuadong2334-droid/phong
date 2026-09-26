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
- `public/fonts/` – font đóng gói sẵn (SIL OFL) để render không cần mạng
- `remotion.config.ts` – cấu hình render

## GitHub Actions

Workflow `.github/workflows/render-video.yml` tự render video khi push lên `main`
(hoặc chạy tay qua tab **Actions → Render video → Run workflow**).
File MP4 được tải về trong mục **Artifacts** của lần chạy.
