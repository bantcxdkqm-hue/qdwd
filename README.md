# Lucid Cart – Hướng dẫn cài đặt và vận hành

Phương án B: Supabase lưu dữ liệu và chấm điểm, Vercel chạy giao diện. Người cài đặt chỉ cần biết dùng trình duyệt; thời gian khoảng 1 giờ.

```
lucid-cart/
├─ supabase/schema.sql   Cơ sở dữ liệu, 12 tình huống, logic chấm điểm
└─ web/
   ├─ index.html         Trang chơi cho sinh viên
   ├─ admin.html         Trang quản trị cho BTC
   └─ config.js          Tệp cấu hình (BTC chỉ sửa tệp này)
```

## Bước 1. Tạo dự án Supabase

1. Vào supabase.com, đăng ký bằng email của BTC.
2. Chọn **New project**. Vùng máy chủ chọn **Southeast Asia (Singapore)** để chạy nhanh ở Việt Nam.
3. Đặt mật khẩu cơ sở dữ liệu và lưu lại ở nơi an toàn.

## Bước 2. Tạo cơ sở dữ liệu

1. Trong dự án, mở **SQL Editor**, chọn **New query**.
2. Dán toàn bộ nội dung `supabase/schema.sql`, bấm **Run**.
3. Dòng kết quả cuối phải là: 12 tình huống, 48 món, 12 món ma túy.

Chạy lại tệp này nhiều lần vẫn an toàn. Muốn sửa câu chữ một tình huống, sửa trong tệp rồi chạy lại.

## Bước 3. Tạo tài khoản quản trị cho BTC

1. Mở **Authentication → Users → Add user → Create new user**. Nhập email và mật khẩu, đánh dấu tự xác nhận email (Auto Confirm).
2. Mở lại **SQL Editor** và chạy, mỗi email một dòng:

```sql
insert into public.lc_admins (email) values ('ten.btc@ueh.edu.vn');
```

3. Nên tắt chức năng tự đăng ký trong phần cài đặt Authentication. Kể cả khi ai đó tự đăng ký, họ cũng không vào được trang quản trị vì email không có trong `lc_admins`.

## Bước 4. Điền tệp cấu hình

Mở `web/config.js`:

- `SUPABASE_URL` và `SUPABASE_ANON_KEY`: lấy trong **Project Settings → API**. Dùng khóa **anon (public)**.
- `register_url`: dán đường dẫn đăng ký Workshop khi có.

**Tuyệt đối không** dán khóa `service_role` hay khóa bí mật vào `config.js`. Khóa anon được thiết kế để công khai. Trình duyệt không đọc thẳng được bảng nào; mọi thao tác đi qua các hàm có kiểm tra quyền.

## Bước 5. Đưa trang web lên mạng (Vercel)

1. Tạo kho GitHub, tải toàn bộ thư mục `lucid-cart` lên.
2. Vào vercel.com, đăng nhập bằng GitHub, chọn **Add New → Project**, chọn kho vừa tạo.
3. Ở mục **Root Directory** chọn `web`. **Framework Preset** chọn **Other**. Không cần lệnh build.
4. Bấm **Deploy**. Sau khoảng 1 phút bạn có:
   - Trang chơi: `https://<tên-dự-án>.vercel.app`
   - Trang quản trị: `https://<tên-dự-án>.vercel.app/admin.html`

Mỗi lần sửa `config.js` trên GitHub, Vercel tự cập nhật trang.

## Bước 6. Chạy thử trước khi mở cửa

1. Vào trang quản trị, tab **Mã vé**, tạo 5 mã, đánh dấu **Mã thử nghiệm**. Mã thử chơi được cả trước ngày 12/11 và không tính vào thống kê.
2. Chơi thử: 1 lượt thắng, 1 lượt thua, 1 lượt bỏ dở giữa chừng rồi nhập lại mã trong 30 phút để kiểm tra chơi tiếp.
3. Kiểm tra trên điện thoại cả iPhone và Android, ở chế độ sáng và tối.
4. Tab **Người hoàn thành**: bật **Hiện cả lượt thử nghiệm** để thấy kết quả vừa chơi.
5. Tab **Tra mã rút thăm**: thử tra một mã hoàn thành.
6. Xóa dữ liệu thử nghiệm bằng lệnh ở mục "Lệnh thường dùng".

## Vận hành trong sự kiện

| Thời điểm | Việc cần làm | Ở đâu |
| --- | --- | --- |
| Trước 12/11 | Tạo lô mã chính thức (ví dụ theo từng ca bán vé), bấm **In mã vé**, cắt và phát kèm khi thu 10.000đ | Tab Mã vé |
| 12–30/11 | Theo dõi số lượt, tỷ lệ thắng, dạng ma túy bị chọn sai nhiều nhất | Tab Thống kê |
| Trước 28/11 | Gửi dạng bị chọn sai nhiều nhất cho báo cáo viên Chuyên đề 2 | Tab Thống kê |
| 28/11 | Rút thăm: tra mã người trúng, bấm **Đánh dấu đã nhận giải** | Tab Tra mã rút thăm |
| Sau sự kiện | Tải **danh sách MSSV (mỗi MSSV một dòng)** để cập nhật hệ thống mã vạch, rồi xóa dữ liệu cá nhân | Tab Người hoàn thành |

## Lệnh thường dùng (chạy trong SQL Editor)

Đổi thời gian mở cửa:

```sql
update public.lc_settings
set opens_at = '2026-11-12 08:00+07', closes_at = '2026-11-30 23:59+07';
```

Nếu BTC chốt "Đúng 5/5 câu" nghĩa là không được sai lần nào:

```sql
update public.lc_settings set max_lives = 1;
```

Tạm ẩn một tình huống (mỗi dạng nên còn ít nhất 2 tình huống để có tình huống chuộc lỗi):

```sql
update public.lc_situations set active = false where id = 'T7';
```

Xóa toàn bộ dữ liệu thử nghiệm:

```sql
delete from public.lc_completions where is_test;
delete from public.lc_plays where ticket_code in (select code from public.lc_tickets where is_test);
delete from public.lc_tickets where is_test;
```

Xóa dữ liệu cá nhân sau khi đã cập nhật quyền lợi (giữ lại số liệu thống kê):

```sql
update public.lc_plays set full_name = '(đã xóa)', mssv = null;
update public.lc_completions set full_name = '(đã xóa)', mssv = null;
```

## Lưu ý

- Dự án Supabase gói miễn phí có thể bị tạm dừng nếu lâu không có hoạt động. Trước ngày 12/11, mở trang quản trị vài ngày một lần và kiểm tra trạng thái dự án trong Dashboard. Giới hạn của các gói miễn phí thay đổi theo thời gian, cần kiểm tra lại trước khi mở cửa.
- Đáp án chỉ nằm trên máy chủ. Trình duyệt chỉ biết món nào là ma túy sau khi người chơi đã chọn.
- Mã vé, mã hoàn thành gồm 8 ký tự ngẫu nhiên, bỏ các ký tự dễ nhầm I, O, 0, 1.
- Nội dung pháp lý trong game cập nhật đến ngày 07/11/2026 (xem mục 2 và 9 của tài liệu kịch bản). Nhờ cán bộ Công an phường hoặc giảng viên luật rà lại trước khi mở cửa.
