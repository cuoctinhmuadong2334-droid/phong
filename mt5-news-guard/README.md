# NewsGuard — chặn vào lệnh quanh tin tức trên MT5

Bộ lọc gắn vào EA để **không mở lệnh mới** quanh các tin lớn của Mỹ. Không đóng hay sửa lệnh đang mở.

| Lớp | Bắt được | Cách hoạt động |
|---|---|---|
| 1. Lịch kinh tế | Tin có lịch: FOMC, CPI, NFP, phát biểu của Powell hoặc Tổng thống (nếu lịch có liệt kê) | Đọc lịch kinh tế có sẵn trong MT5, cập nhật 5 phút/lần |
| 2. Sốc giá | Tin bất ngờ, kể cả bài đăng trên Truth Social | Nến M1 dài hơn 3 lần trung bình, hoặc spread vượt ngưỡng: chặn 15 phút |

> **Lưu ý:** không công cụ miễn phí nào báo trước được bài đăng bất ngờ. Lớp 2 chỉ chặn **sau khi** giá đã bắt đầu chạy (trong vòng vài giây). Lệnh đang mở vẫn cần stop loss.

## 1. Cài đặt

1. Trong MT5: **File → Open Data Folder**, mở thư mục `MQL5`.
2. Chép `Include/NewsGuard.mqh` vào `MQL5/Include/`.
3. Chép `Experts/NewsGuardDemo.mq5` vào `MQL5/Experts/`.
4. Mở `NewsGuardDemo.mq5` trong MetaEditor (F4), bấm **Compile** (F7). Nếu có lỗi, chụp tab Errors gửi lại.

## 2. Chạy thử trên tài khoản demo

1. Kéo **NewsGuardDemo** vào chart XAUUSD. EA này **không vào lệnh**.
2. Góc trái chart hiện trạng thái, ví dụ:
   - `NewsGuard: OK - next: Nonfarm Payrolls at 2026.11.06 15:30`
   - `NewsGuard: BLOCKED - NEWS: Fed Chair Powell Speech at 21:00 (in 12 min)`
3. Tab **Experts** (dưới cùng) liệt kê các tin USD trong 24 giờ tới. Dựa vào danh sách này để biết lịch của broker có tin phát biểu của Tổng thống hay không.

Giờ hiển thị là **giờ server của broker**, giống giờ trên chart.

## 3. Gắn vào EA của bạn

Thêm vào đầu file EA, **sau** các dòng `input` của EA:

```mq5
#include <NewsGuard.mqh>
```

Trước **mỗi** chỗ mở lệnh mới (`OrderSend`, `trade.Buy`, `trade.Sell`, `trade.BuyLimit`…):

```mq5
string why;
if(NewsGuard_IsBlocked(why)) { Comment(why); return; }
```

Gửi file `.mq5` của bạn, mình sẽ gắn giúp vào đúng chỗ.

## 4. Thông số (tab Inputs của EA, có chữ "NG:")

| Thông số | Mặc định | Ý nghĩa |
|---|---|---|
| `InpNG_Enable` | true | Bật/tắt |
| `InpNG_MinutesBefore` | 30 | Số phút chặn trước tin |
| `InpNG_MinutesAfter` | 30 | Số phút chặn sau tin |
| `InpNG_Currencies` | USD | Tiền tệ theo dõi, cách nhau bằng dấu phẩy |
| `InpNG_MinImportance` | High | Chặn mọi tin từ mức này trở lên |
| `InpNG_Keywords` | trump,president,powell,fed-chair | Tin có từ khóa này thì chặn từ mức Moderate |
| `InpNG_SpikeGuard` | true | Bật lớp sốc giá |
| `InpNG_SpikeMult` | 3.0 | Nến M1 dài hơn X lần trung bình 60 nến thì coi là sốc. Giảm xuống thì nhạy hơn |
| `InpNG_MaxSpreadPts` | 0 (tắt) | Spread (point) vượt mức này thì chặn. Xem spread bình thường của broker trước khi đặt |
| `InpNG_SpikeCooldownMin` | 15 | Số phút chặn sau mỗi cú sốc |

## Giới hạn

- **Không thấy trước** bài đăng bất ngờ. Lớp sốc giá chỉ chặn sau khi giá đã chạy.
- Lịch kinh tế do MetaQuotes cung cấp. Có thể thiếu một số bài phát biểu, nhất là phát biểu không có giờ cố định (các tin này bị bỏ qua).
- **Strategy Tester không có lịch kinh tế**: khi backtest chỉ lớp sốc giá hoạt động.
- Lớp sốc giá theo dõi mã của chart đang gắn EA. EA giao dịch nhiều mã thì chỉ mã trên chart được kiểm tra.
- Sau giờ mở cửa thứ Hai, nến gap có thể làm lớp sốc giá chặn 15 phút đầu tuần.
