-- =====================================================================
-- LUCID CART – Cơ sở dữ liệu và logic máy chủ (Supabase / PostgreSQL)
-- Cách dùng: Supabase Dashboard → SQL Editor → New query → dán toàn bộ
-- tệp này → Run. Chạy lại nhiều lần vẫn an toàn (nội dung được cập nhật).
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------
-- 1. BẢNG
-- ---------------------------------------------------------------------

-- Cấu hình chung (chỉ 1 dòng). Sửa bằng lệnh UPDATE ở cuối README.
create table if not exists public.lc_settings (
  id             int primary key default 1 check (id = 1),
  opens_at       timestamptz not null default '2026-11-12 00:00:00+07',
  closes_at      timestamptz not null default '2026-11-30 23:59:59+07',
  max_lives      int not null default 2 check (max_lives between 1 and 3),
  resume_minutes int not null default 30
);
insert into public.lc_settings (id) values (1) on conflict (id) do nothing;

-- Email các thành viên BTC được vào trang quản trị.
create table if not exists public.lc_admins (
  email text primary key
);

create table if not exists public.lc_tickets (
  code       text primary key,                 -- 8 ký tự, không gạch nối
  batch      text not null default 'default',
  is_test    boolean not null default false,   -- mã thử: bỏ qua giờ mở cửa, không tính thống kê
  status     text not null default 'new' check (status in ('new','playing','used')),
  created_at timestamptz not null default now(),
  used_at    timestamptz
);

create table if not exists public.lc_situations (
  id        text primary key,                  -- T1 … T12
  form_type int  not null check (form_type between 1 and 5),
  variant   text not null,                     -- 1, 2, 3a, 3b, 4a, 4b, 5
  context   text not null check (context in ('via_he','tap_hoa','quan_nuoc')),
  title     text not null,
  intro     text not null,
  lesson    text not null,
  active    boolean not null default true
);

create table if not exists public.lc_items (
  id           uuid primary key default gen_random_uuid(),  -- mã ngẫu nhiên, không lộ đáp án
  situation_id text not null references public.lc_situations(id) on delete cascade,
  label        text not null,
  price        text,
  icon         text not null default 'box',
  detail       text not null,
  is_drug      boolean not null default false,
  is_decoy     boolean not null default false,
  unique (situation_id, label)
);

create table if not exists public.lc_plays (
  id                uuid primary key default gen_random_uuid(),
  token             uuid not null default gen_random_uuid(),
  ticket_code       text not null unique references public.lc_tickets(code),
  full_name         text not null,
  mssv              text,
  age_group         text not null,
  role              text not null,
  consent           boolean not null,
  form_order        int[] not null,             -- thứ tự 5 dạng, xáo ngẫu nhiên
  step              int not null default 0,     -- số dạng đã vượt qua (0–5)
  lives             int not null,
  score             int not null default 0,
  current_situation text references public.lc_situations(id),
  used_situations   text[] not null default '{}',
  status            text not null default 'playing'
                    check (status in ('playing','won','lost','abandoned')),
  started_at        timestamptz not null default now(),
  last_seen         timestamptz not null default now(),
  ended_at          timestamptz
);

create table if not exists public.lc_answers (
  id           bigint generated always as identity primary key,
  play_id      uuid not null references public.lc_plays(id) on delete cascade,
  situation_id text not null references public.lc_situations(id),
  item_id      uuid not null references public.lc_items(id),
  correct      boolean not null,
  inspected    int not null default 0,
  created_at   timestamptz not null default now()
);

create table if not exists public.lc_completions (
  code        text primary key,                 -- LC-XXXX-XXXX
  play_id     uuid not null unique references public.lc_plays(id) on delete cascade,
  ticket_code text not null,
  full_name   text not null,
  mssv        text,
  is_test     boolean not null default false,
  created_at  timestamptz not null default now(),
  redeemed    boolean not null default false,
  redeemed_at timestamptz
);

-- Bật RLS và không tạo policy nào: trình duyệt KHÔNG đọc thẳng được bảng.
-- Mọi truy cập đi qua các hàm bên dưới.
alter table public.lc_settings    enable row level security;
alter table public.lc_admins      enable row level security;
alter table public.lc_tickets     enable row level security;
alter table public.lc_situations  enable row level security;
alter table public.lc_items       enable row level security;
alter table public.lc_plays       enable row level security;
alter table public.lc_answers     enable row level security;
alter table public.lc_completions enable row level security;

-- ---------------------------------------------------------------------
-- 2. NỘI DUNG 12 TÌNH HUỐNG (theo tài liệu kịch bản, mục 4)
-- Tên thương hiệu đều hư cấu. Chạy lại tệp sẽ cập nhật nội dung.
-- ---------------------------------------------------------------------

insert into public.lc_situations (id, form_type, variant, context, title, intro, lesson) values
('T1', 1, '1', 'tap_hoa', 'Quầy thu ngân cửa hàng tiện lợi',
 '23 giờ, bạn ghé cửa hàng gần ký túc xá mua đồ ôn thi. Một anh đứng cạnh quầy mở balo: “Thi căng hả? Thử cái này, ngủ ngon, hút không lên test đâu.”',
 'Mọi thuốc lá điện tử đều bị cấm tại Việt Nam. Giá cao bất thường và câu “hút không lên test” là dấu hiệu của ma túy Etomidate ngụy trang.'),
('T2', 1, '1', 'quan_nuoc', 'Sân thượng quán cà phê',
 'Nhóm bạn cùng lớp mừng sinh nhật. Một bạn chuyền tay chiếc pod mùi xoài: “Hút một hơi thôi, tinh dầu thư giãn, không phải ma túy đâu.”',
 'Lời rủ “một hơi thôi”, “không phải ma túy” cùng biểu hiện lạ của người vừa dùng là dấu hiệu nguy hiểm. Chuyền pod cho bạn bè có thể bị xử lý về tội tổ chức sử dụng trái phép chất ma túy.'),
('T3', 3, '3a', 'tap_hoa', 'Tiệm tạp hóa trong hẻm trọ',
 'Bạn mua đồ uống cho buổi họp nhóm. Chủ tiệm chỉ vào hộp nhỏ cạnh máy tính tiền: “Hàng mới về, pha một gói cho cả nhóm, bật nhạc lên là vui cả đêm.”',
 'Gói nhỏ bao bì bắt mắt, giá cao vô lý, lời mời “vui cả đêm” là dấu hiệu của “nước vui”. Đường dây thật từng dùng các nhãn Chali, Deadpool, Coffee, Crispy Fruit.'),
('T4', 4, '4a', 'via_he', 'Xe đẩy bánh kẹo trước cổng trường',
 'Giờ giải lao, bạn mua đồ ăn vặt. Người bán: “Hàng xách tay Mỹ nè, ăn một viên là lâng lâng.”',
 'Chữ THC, Cannabis, Medicated, “21+”, hình lá cần sa là dấu hiệu kẹo chứa cần sa. Tại Việt Nam, mọi sản phẩm chứa THC đều là ma túy, dù ở nước ngoài được bán hợp pháp.'),
('T5', 4, '4a', 'tap_hoa', 'Kệ hàng xách tay ở tiệm tạp hóa',
 'Bạn tìm quà sinh nhật cho bạn cùng phòng. Kệ “hàng xách tay” bày đủ loại bánh kẹo nhãn nước ngoài.',
 'Chữ “Infused”, “Activates in…”, thanh kẹo chia ô theo liều là dấu hiệu bánh kẹo tẩm cần sa. Tác dụng đến chậm nên người dùng dễ ăn thêm và ngộ độc nặng.'),
('T6', 3, '3b', 'quan_nuoc', 'Quán trà sữa, hẹn người quen qua mạng',
 'Lần đầu gặp người quen qua ứng dụng. Bạn đi rửa tay, quay lại thấy người kia đã “gọi giúp” một ly. Bạn sẽ uống gì?',
 'GHB (“nước biển”) không màu, không mùi, không nhìn thấy được. Cách phòng duy nhất là không uống ly đã rời khỏi tầm mắt bạn.'),
('T7', 4, '4b', 'via_he', 'Sạp phụ kiện ở phố đi bộ',
 'Bạn mua sticker dán laptop. Người bán hạ giọng: “Có loại đặc biệt, đặt lên lưỡi, nhìn đâu cũng thấy cầu vồng.”',
 '“Sticker” không keo, chia ô nhỏ, bán lẻ từng ô giá cao, kèm lời dặn “đặt lên lưỡi” là dấu hiệu tem giấy tẩm LSD.'),
('T8', 3, '3a', 'quan_nuoc', 'Quán “cà phê chill” trong hẻm',
 'Một trang mạng xã hội quảng cáo quán có “menu ẩn cho khách quen”, đặt qua tin nhắn riêng. Bạn rủ nhóm bạn đến thử.',
 'Món không có trên menu, đặt qua kênh kín, giá gấp 10 lần, quảng cáo bằng tác dụng “hưng phấn” là dấu hiệu đồ uống pha ma túy.'),
('T9', 2, '2', 'tap_hoa', 'Kệ hàng nhập ở tiệm tạp hóa',
 'Bạn tìm thứ giúp ngủ ngon mùa thi. Chủ tiệm giới thiệu: “Thảo mộc Mỹ, có CBD, cuốn hút hay đốt đều thư giãn.”',
 '“Thảo mộc” ghi “không dùng cho người”, có chữ CBD, gói nhỏ giá cao, được gợi ý để hút là dấu hiệu thảo mộc tẩm cần sa tổng hợp.'),
('T10', 2, '2', 'via_he', 'Góc vỉa hè gần ký túc xá',
 'Một nhóm đứng ở góc đường mời bạn: “Tobacco hàng Mỹ, một hơi là bay, không nghiện đâu.”',
 'Điếu cuốn sẵn giá cao bất thường, tên lóng “tobacco”, “cỏ”, lời hứa “bay” và “không nghiện” là dấu hiệu thuốc lá tẩm cần sa tổng hợp.'),
('T11', 5, '5', 'quan_nuoc', 'Tiệc trên sân thượng quán giải khát',
 'Bạn của bạn tổ chức tiệc. Một người lạ đưa túi zip: “Kẹo năng lượng, ngậm một viên nhảy tới sáng.”',
 'Viên nén màu sắc in logo, bán lẻ trong túi zip, quảng cáo “nhảy tới sáng” là dấu hiệu thuốc lắc.'),
('T12', 5, '5', 'tap_hoa', 'Quầy tạp hóa gần khu trọ',
 'Bạn mua đồ cho tiệc sinh nhật phòng trọ. Người bán: “Có bột hồng hương dâu, rắc vào nước cho cả bàn cùng vui.”',
 'Bột màu không nhãn, giá cao, gọi bằng tên lóng, gợi ý “rắc vào nước cho cả bàn” là dấu hiệu ma túy dạng bột hồng. Rủ cả bàn cùng dùng có thể bị xử lý về tội tổ chức sử dụng trái phép chất ma túy.')
on conflict (id) do update set
  form_type = excluded.form_type, variant = excluded.variant, context = excluded.context,
  title = excluded.title, intro = excluded.intro, lesson = excluded.lesson;

insert into public.lc_items (situation_id, label, price, icon, detail, is_drug, is_decoy) values
-- T1
('T1', 'Đầu pod “MOOD Berry Chill”', '1.800.000đ', 'device', 'Nhỏ như chiếc USB, mùi dâu ngọt. Không nhãn tiếng Việt, không nhà sản xuất. Được mời từ balo, không bày trên kệ. Lời quảng cáo: “ngủ ngon”, “không lên test”.', true, false),
('T1', 'Hộp kẹo ngậm bạc hà hình USB', '25.000đ', 'tin', 'Trông như thiết bị điện tử, nhưng có tem phụ tiếng Việt, hạn sử dụng và nằm trên kệ hàng.', false, true),
('T1', 'Lon cà phê sữa', '15.000đ', 'can', 'Nhãn đầy đủ, lấy từ tủ lạnh của cửa hàng.', false, false),
('T1', 'Gói bánh mì que', '12.000đ', 'snack', 'Nhãn đầy đủ, có hóa đơn.', false, false),
-- T2
('T2', 'Pod mùi xoài đang chuyền tay', 'Được mời', 'device', 'Vỏ trơn, không nhãn. Người vừa hút ngồi lặng, nói chậm, đứng dậy thì loạng choạng.', true, false),
('T2', 'Ly soda việt quất tím đậm', '39.000đ', 'cup', 'Màu lạ, nhưng là món trong menu. Bạn tự gọi và nhận tận tay.', false, true),
('T2', 'Bánh kem sinh nhật', 'Đã mua', 'cake', 'Mua ở tiệm bánh, có hóa đơn.', false, false),
('T2', 'Ly trà đào', '35.000đ', 'cup', 'Món trong menu, bạn tự gọi.', false, false),
-- T3
('T3', 'Gói bột “Fruity Joy” 15g', '300.000đ', 'packet', 'In hình trái cây biết cười, bao bì bóng. Không nhãn tiếng Việt, không hạn sử dụng, không nhà sản xuất. Không bày trên kệ, đắt gấp 30 lần nước pha thường.', true, false),
('T3', 'Gói bột cam pha uống nhập khẩu', '8.000đ', 'packet', 'Chữ nước ngoài, nhưng có tem phụ tiếng Việt ghi nhà nhập khẩu và hạn sử dụng. Bày trên kệ.', false, true),
('T3', 'Hộp cà phê hòa tan 20 gói', '65.000đ', 'box', 'Nhãn đầy đủ.', false, false),
('T3', 'Lốc sữa chua uống', '28.000đ', 'bottle', 'Nhãn đầy đủ, để trong tủ lạnh.', false, false),
-- T4
('T4', 'Gói kẹo dẻo “Happy Bears”', '150.000đ', 'candy', 'Nhãn tiếng Anh có chữ “Medicated”, “THC 500mg”, “21+” và hình lá 7 cánh. Không tem phụ tiếng Việt.', true, false),
('T4', 'Kẹo dẻo Hàn Quốc vị đào', '25.000đ', 'candy', 'Nhãn tiếng Hàn, có tem phụ tiếng Việt và hạn sử dụng.', false, true),
('T4', 'Bánh tráng trộn', '20.000đ', 'food', 'Làm tại chỗ.', false, false),
('T4', 'Chai nước suối', '6.000đ', 'bottle', 'Nắp còn nguyên seal.', false, false),
-- T5
('T5', 'Thanh socola “Cosmic Bar”', '220.000đ', 'bar', 'Nhãn tiếng Anh: “Infused”, “Activates in 60 min”, “Keep away from children”. Chia sẵn 10 ô “liều”. Không tem phụ.', true, false),
('T5', 'Socola đen Bỉ hộp sang', '180.000đ', 'bar', 'Nhãn ngoại, có tem phụ tiếng Việt và hóa đơn.', false, true),
('T5', 'Hộp bánh quy bơ', '95.000đ', 'box', 'Nhãn đầy đủ.', false, false),
('T5', 'Gấu bông nhỏ', '120.000đ', 'gift', 'Đồ chơi có tem hợp quy.', false, false),
-- T6
('T6', 'Ly trà vải được gọi giúp', 'Được mời', 'cup', 'Đã bóc màng, cắm sẵn ống hút. Bạn không thấy lúc pha.', true, false),
('T6', 'Ly sâm bí đao nâu đục', '20.000đ', 'cup', 'Màu lạ, nhưng là đồ uống truyền thống. Bạn tự gọi, nhận tận tay.', false, true),
('T6', 'Ly trà sữa bạn tự gọi', '35.000đ', 'cup', 'Màng ép còn nguyên, nhận từ quầy.', false, false),
('T6', 'Chai nước suối', '8.000đ', 'bottle', 'Nắp còn seal.', false, false),
-- T7
('T7', 'Tấm giấy 25 ô in hình hoạt hình', '250.000đ/ô', 'stamps', 'Mỗi ô khoảng 1,5cm, giấy thấm mỏng, không có keo, đựng trong túi zip nhỏ.', true, false),
('T7', 'Sticker hologram dán laptop', '15.000đ', 'sticker', 'Có lớp keo và giấy đế bóc được.', false, true),
('T7', 'Móc khóa acrylic', '30.000đ', 'gift', 'Đồ trang trí thường.', false, false),
('T7', 'Bưu thiếp', '10.000đ', 'card', 'Đồ trang trí thường.', false, false),
-- T8
('T8', '“Trà sữa Party” combo nhóm', '350.000đ/ly', 'cup', 'Không có trong menu in. Chỉ đặt qua tin nhắn riêng. Lời mời: “uống xong quẩy tới sáng”.', true, false),
('T8', 'Cà phê muối', '30.000đ', 'cup', 'Vị lạ nhưng là món phổ biến, có trong menu.', false, true),
('T8', 'Nước ép cam', '35.000đ', 'cup', 'Trong menu, ép tại quầy.', false, false),
('T8', 'Trà sữa trân châu', '35.000đ', 'cup', 'Trong menu.', false, false),
-- T9
('T9', 'Gói “Zen Herbal Blend” 3g', '450.000đ', 'herb', 'Bao bì kim tuyến. Nhãn tiếng Anh: “Herbal incense”, “Not for human consumption”, “CBD relax”. Không tem phụ, không nhà nhập khẩu.', true, false),
('T9', 'Hộp trà atiso túi lọc', '40.000đ', 'box', 'Cũng là thảo mộc, nhưng có nhãn tiếng Việt, cơ sở sản xuất, hạn sử dụng.', false, true),
('T9', 'Hộp sữa tươi', '9.000đ', 'milk', 'Nhãn đầy đủ.', false, false),
('T9', 'Gói hạt điều rang', '60.000đ', 'packet', 'Nhãn đầy đủ.', false, false),
-- T10
('T10', 'Điếu thuốc cuốn tay “tobacco”', '100.000đ/điếu', 'cigarette', 'Không nhãn, không tem, mùi lạ. Người vừa hút cười lớn, mắt đỏ, rồi hoảng hốt.', true, false),
('T10', 'Gói hạt hướng dương túi zip', '15.000đ', 'packet', 'Trông như hàng tự làm, nhưng có nhãn cơ sở sản xuất và hạn sử dụng.', false, true),
('T10', 'Bắp xào', '15.000đ', 'food', 'Làm tại chỗ.', false, false),
('T10', 'Chai trà đóng chai', '12.000đ', 'bottle', 'Nắp còn seal.', false, false),
-- T11
('T11', 'Viên nén nhiều màu in logo', '500.000đ/viên', 'pills', 'Đựng trong túi zip, không nhãn, không hộp. Mỗi viên in hình logo.', true, false),
('T11', 'Tuýp viên sủi vitamin C', '45.000đ', 'tube', 'Viên nén màu cam, nhưng tuýp có nhãn tiếng Việt, số đăng ký, hạn sử dụng.', false, true),
('T11', 'Chai nước suối', '10.000đ', 'bottle', 'Nắp còn seal.', false, false),
('T11', 'Đĩa trái cây', '60.000đ', 'fruit', 'Quán phục vụ.', false, false),
-- T12
('T12', 'Túi zip nhỏ bột màu hồng', '800.000đ/túi', 'powder', 'Không nhãn. Được gọi là “ngựa hồng”, “bột dâu”. Cất dưới quầy.', true, false),
('T12', 'Gói bột rau câu vị dâu', '12.000đ', 'packet', 'Màu hồng giống hệt, nhưng có nhãn tiếng Việt, thành phần, hạn sử dụng.', false, true),
('T12', 'Hộp sữa dâu', '8.000đ', 'milk', 'Nhãn đầy đủ.', false, false),
('T12', 'Bộ nến và mũ sinh nhật', '35.000đ', 'gift', 'Đồ trang trí.', false, false)
on conflict (situation_id, label) do update set
  price = excluded.price, icon = excluded.icon, detail = excluded.detail,
  is_drug = excluded.is_drug, is_decoy = excluded.is_decoy;

-- ---------------------------------------------------------------------
-- 3. HÀM NỘI BỘ
-- ---------------------------------------------------------------------

-- Mã ngẫu nhiên, bỏ các ký tự dễ nhầm (I, O, 0, 1). 32 ký tự → không lệch.
create or replace function public.lc_gen_code(len int) returns text
language plpgsql volatile set search_path = public, extensions as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  b bytea := extensions.gen_random_bytes(len);
  res text := '';
  i int;
begin
  for i in 0 .. len - 1 loop
    res := res || substr(alphabet, (get_byte(b, i) % 32) + 1, 1);
  end loop;
  return res;
end $$;

create or replace function public.lc_norm(p text) returns text
language sql immutable as $$
  select upper(regexp_replace(coalesce(p, ''), '[^A-Za-z0-9]', '', 'g'))
$$;

-- Tình huống gửi xuống trình duyệt: KHÔNG kèm đáp án, món được xáo thứ tự.
create or replace function public.lc_situation_json(p_sid text) returns jsonb
language sql volatile set search_path = public as $$
  select jsonb_build_object(
    'id', s.id, 'context', s.context, 'title', s.title, 'intro', s.intro,
    'items', (select jsonb_agg(jsonb_build_object(
                'id', i.id, 'label', i.label, 'price', i.price,
                'icon', i.icon, 'detail', i.detail) order by random())
              from public.lc_items i where i.situation_id = s.id))
  from public.lc_situations s where s.id = p_sid
$$;

create or replace function public.lc_pick_situation(p_form int, p_exclude text[]) returns text
language sql volatile set search_path = public as $$
  select id from public.lc_situations
  where form_type = p_form and active and not (id = any (coalesce(p_exclude, '{}')))
  order by random() limit 1
$$;

create or replace function public.lc_state_json(p public.lc_plays) returns jsonb
language sql stable set search_path = public as $$
  select jsonb_build_object(
    'play_id', p.id, 'token', p.token, 'lives', p.lives,
    'max_lives', (select max_lives from public.lc_settings where id = 1),
    'score', p.score, 'step', p.step, 'total', 5, 'status', p.status,
    'full_name', p.full_name)
$$;

-- ---------------------------------------------------------------------
-- 4. HÀM CHO NGƯỜI CHƠI (gọi từ trang game)
-- ---------------------------------------------------------------------

create or replace function public.lc_check_ticket(p_code text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_code text := public.lc_norm(p_code);
  t  public.lc_tickets;
  st public.lc_settings;
  p  public.lc_plays;
begin
  select * into st from public.lc_settings where id = 1;
  select * into t from public.lc_tickets where code = v_code;
  if not found then
    return jsonb_build_object('status', 'invalid');
  end if;
  if not t.is_test and (now() < st.opens_at or now() > st.closes_at) then
    return jsonb_build_object('status', 'closed');
  end if;
  if t.status = 'new' then
    return jsonb_build_object('status', 'new');
  end if;
  if t.status = 'playing' then
    select * into p from public.lc_plays where ticket_code = v_code;
    if found and p.status = 'playing'
       and p.last_seen > now() - make_interval(mins => st.resume_minutes) then
      return jsonb_build_object('status', 'resume');
    end if;
    -- Quá thời gian chờ: đóng lượt chơi bỏ dở.
    update public.lc_plays set status = 'abandoned', ended_at = now()
      where ticket_code = v_code and status = 'playing';
    update public.lc_tickets set status = 'used' where code = v_code;
    return jsonb_build_object('status', 'expired');
  end if;
  return jsonb_build_object('status', 'used');
end $$;

create or replace function public.lc_start(
  p_code text, p_full_name text, p_mssv text,
  p_age_group text, p_role text, p_consent boolean
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_code  text := public.lc_norm(p_code);
  v_name  text := btrim(regexp_replace(coalesce(p_full_name, ''), '\s+', ' ', 'g'));
  v_mssv  text := nullif(regexp_replace(coalesce(p_mssv, ''), '\s', '', 'g'), '');
  t  public.lc_tickets;
  st public.lc_settings;
  p  public.lc_plays;
  v_order int[];
  v_sid text;
begin
  if not coalesce(p_consent, false) then raise exception 'LC_CONSENT'; end if;
  if char_length(v_name) < 2 or char_length(v_name) > 80 then raise exception 'LC_NAME'; end if;
  if p_age_group is null or p_age_group not in ('duoi_18', '18_22', '23_30', 'tren_30') then
    raise exception 'LC_AGE';
  end if;
  if p_role is null or p_role not in ('sinh_vien', 'hoc_sinh', 'can_bo', 'khac') then
    raise exception 'LC_ROLE';
  end if;
  if p_role = 'sinh_vien' and v_mssv is null then raise exception 'LC_MSSV_REQUIRED'; end if;
  if v_mssv is not null and v_mssv !~ '^[0-9]{6,12}$' then raise exception 'LC_MSSV'; end if;

  select * into st from public.lc_settings where id = 1;
  select * into t from public.lc_tickets where code = v_code for update;
  if not found then raise exception 'LC_TICKET_INVALID'; end if;
  if t.status <> 'new' then raise exception 'LC_TICKET_USED'; end if;
  if not t.is_test and (now() < st.opens_at or now() > st.closes_at) then
    raise exception 'LC_CLOSED';
  end if;

  select array_agg(f order by random()) into v_order from generate_series(1, 5) as f;
  v_sid := public.lc_pick_situation(v_order[1], '{}');

  update public.lc_tickets set status = 'playing', used_at = now() where code = v_code;
  insert into public.lc_plays (ticket_code, full_name, mssv, age_group, role, consent,
                               form_order, lives, current_situation, used_situations)
  values (v_code, v_name, v_mssv, p_age_group, p_role, true,
          v_order, st.max_lives, v_sid, array[v_sid])
  returning * into p;

  return public.lc_state_json(p) || jsonb_build_object('situation', public.lc_situation_json(v_sid));
end $$;

create or replace function public.lc_resume(p_code text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_code text := public.lc_norm(p_code);
  st public.lc_settings;
  p  public.lc_plays;
begin
  select * into st from public.lc_settings where id = 1;
  select * into p from public.lc_plays
    where ticket_code = v_code and status = 'playing'
      and last_seen > now() - make_interval(mins => st.resume_minutes)
    for update;
  if not found then raise exception 'LC_NO_RESUME'; end if;
  update public.lc_plays set last_seen = now() where id = p.id;
  return public.lc_state_json(p) || jsonb_build_object('situation', public.lc_situation_json(p.current_situation));
end $$;

create or replace function public.lc_answer(
  p_play uuid, p_token uuid, p_item uuid, p_inspected int
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  st   public.lc_settings;
  p    public.lc_plays;
  it   public.lc_items;
  s    public.lc_situations;
  drug public.lc_items;
  v_correct  boolean;
  v_inspect  int := greatest(0, least(coalesce(p_inspected, 0), 4));
  v_gain     int := 0;
  v_next     text;
  v_code     text;
  v_raw      text;
  v_is_test  boolean;
  v_result   jsonb;
begin
  select * into st from public.lc_settings where id = 1;
  select * into p from public.lc_plays where id = p_play and token = p_token for update;
  if not found then raise exception 'LC_PLAY_INVALID'; end if;
  if p.status <> 'playing' then raise exception 'LC_PLAY_ENDED'; end if;

  select * into it from public.lc_items where id = p_item and situation_id = p.current_situation;
  if not found then raise exception 'LC_ITEM_INVALID'; end if;
  select * into s from public.lc_situations where id = p.current_situation;
  select * into drug from public.lc_items where situation_id = s.id and is_drug limit 1;

  v_correct := not it.is_drug;
  insert into public.lc_answers (play_id, situation_id, item_id, correct, inspected)
  values (p.id, s.id, it.id, v_correct, v_inspect);

  if v_correct then
    v_gain := 100 + case when v_inspect >= 2 then 20 else 0 end;
    p.score := p.score + v_gain;
    p.step  := p.step + 1;
    if p.step >= 5 then
      p.status := 'won';
      p.ended_at := now();
      p.current_situation := null;
      loop
        v_raw  := public.lc_gen_code(8);
        v_code := 'LC-' || substr(v_raw, 1, 4) || '-' || substr(v_raw, 5, 4);
        exit when not exists (select 1 from public.lc_completions where code = v_code);
      end loop;
      select is_test into v_is_test from public.lc_tickets where code = p.ticket_code;
      insert into public.lc_completions (code, play_id, ticket_code, full_name, mssv, is_test)
      values (v_code, p.id, p.ticket_code, p.full_name, p.mssv, coalesce(v_is_test, false));
    else
      v_next := public.lc_pick_situation(p.form_order[p.step + 1], p.used_situations);
    end if;
  else
    p.lives := p.lives - 1;
    if p.lives <= 0 then
      p.status := 'lost';
      p.ended_at := now();
      p.current_situation := null;
    else
      -- Cơ hội chuộc lỗi: tình huống khác của CÙNG dạng.
      v_next := coalesce(public.lc_pick_situation(s.form_type, p.used_situations),
                         public.lc_pick_situation(s.form_type, '{}'));
    end if;
  end if;

  if v_next is not null then
    p.current_situation := v_next;
    p.used_situations := p.used_situations || v_next;
  end if;
  if p.status <> 'playing' then
    update public.lc_tickets set status = 'used' where code = p.ticket_code;
  end if;

  update public.lc_plays set
    step = p.step, lives = p.lives, score = p.score, status = p.status,
    ended_at = p.ended_at, current_situation = p.current_situation,
    used_situations = p.used_situations, last_seen = now()
  where id = p.id;

  v_result := public.lc_state_json(p) || jsonb_build_object(
    'correct', v_correct, 'gain', v_gain, 'chosen', it.id,
    'drug_item', drug.id, 'drug_label', drug.label,
    'situation_id', s.id, 'variant', s.variant, 'form_type', s.form_type,
    'lesson', s.lesson);

  if v_code is not null then
    v_result := v_result || jsonb_build_object('completion_code', v_code);
  end if;
  if v_next is not null then
    v_result := v_result || jsonb_build_object('next', public.lc_situation_json(v_next));
  end if;
  if p.status <> 'playing' then
    v_result := v_result || jsonb_build_object('wrong', coalesce((
      select jsonb_agg(jsonb_build_object(
               'situation_id', a.situation_id, 'variant', s2.variant,
               'title', s2.title, 'label', i2.label) order by a.created_at)
      from public.lc_answers a
      join public.lc_situations s2 on s2.id = a.situation_id
      join public.lc_items i2 on i2.id = a.item_id
      where a.play_id = p.id and not a.correct), '[]'::jsonb));
  end if;
  return v_result;
end $$;

-- ---------------------------------------------------------------------
-- 5. HÀM CHO TRANG QUẢN TRỊ (chỉ email có trong lc_admins)
-- ---------------------------------------------------------------------

create or replace function public.lc_is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.lc_admins
    where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  )
$$;

create or replace function public.lc_admin_create_tickets(
  p_count int, p_batch text, p_test boolean
) returns setof text
language plpgsql security definer set search_path = public as $$
declare
  i int;
  c text;
  v_batch text := coalesce(nullif(btrim(p_batch), ''), 'default');
begin
  if not public.lc_is_admin() then raise exception 'LC_FORBIDDEN'; end if;
  if p_count is null or p_count < 1 or p_count > 2000 then raise exception 'LC_COUNT'; end if;
  for i in 1 .. p_count loop
    loop
      c := public.lc_gen_code(8);
      begin
        insert into public.lc_tickets (code, batch, is_test)
        values (c, v_batch, coalesce(p_test, false));
        exit;
      exception when unique_violation then
        null;  -- trùng mã (rất hiếm): vòng lặp sinh mã khác
      end;
    end loop;
    return next c;
  end loop;
end $$;

create or replace function public.lc_admin_batches() returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if not public.lc_is_admin() then raise exception 'LC_FORBIDDEN'; end if;
  return coalesce((
    select jsonb_agg(x order by x ->> 'created_at' desc) from (
      select jsonb_build_object(
        'batch', batch, 'is_test', bool_or(is_test), 'total', count(*),
        'used', count(*) filter (where status <> 'new'),
        'created_at', min(created_at)) as x
      from public.lc_tickets group by batch
    ) q), '[]'::jsonb);
end $$;

create or replace function public.lc_admin_tickets(p_batch text) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if not public.lc_is_admin() then raise exception 'LC_FORBIDDEN'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'code', code, 'batch', batch, 'is_test', is_test, 'status', status,
      'created_at', created_at, 'used_at', used_at) order by created_at, code)
    from public.lc_tickets where batch = p_batch), '[]'::jsonb);
end $$;

create or replace function public.lc_admin_completions(p_include_test boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if not public.lc_is_admin() then raise exception 'LC_FORBIDDEN'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'code', c.code, 'full_name', c.full_name, 'mssv', c.mssv, 'is_test', c.is_test,
      'created_at', c.created_at, 'redeemed', c.redeemed, 'redeemed_at', c.redeemed_at,
      'score', p.score, 'lives', p.lives) order by c.created_at desc)
    from public.lc_completions c join public.lc_plays p on p.id = c.play_id
    where coalesce(p_include_test, false) or not c.is_test), '[]'::jsonb);
end $$;

create or replace function public.lc_admin_redeem(p_code text, p_mark boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v text := public.lc_norm(p_code);
  c public.lc_completions;
begin
  if not public.lc_is_admin() then raise exception 'LC_FORBIDDEN'; end if;
  if left(v, 2) = 'LC' and char_length(v) = 10 then
    v := 'LC-' || substr(v, 3, 4) || '-' || substr(v, 7, 4);
  end if;
  select * into c from public.lc_completions where code = v;
  if not found then raise exception 'LC_NOT_FOUND'; end if;
  if coalesce(p_mark, false) and not c.redeemed then
    update public.lc_completions set redeemed = true, redeemed_at = now()
      where code = v returning * into c;
  end if;
  return jsonb_build_object('code', c.code, 'full_name', c.full_name, 'mssv', c.mssv,
    'is_test', c.is_test, 'created_at', c.created_at,
    'redeemed', c.redeemed, 'redeemed_at', c.redeemed_at);
end $$;

create or replace function public.lc_admin_stats() returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if not public.lc_is_admin() then raise exception 'LC_FORBIDDEN'; end if;
  return jsonb_build_object(
    'tickets_total', (select count(*) from public.lc_tickets where not is_test),
    'tickets_used',  (select count(*) from public.lc_tickets where not is_test and status <> 'new'),
    'won',     (select count(*) from public.lc_plays p join public.lc_tickets t on t.code = p.ticket_code
                where not t.is_test and p.status = 'won'),
    'lost',    (select count(*) from public.lc_plays p join public.lc_tickets t on t.code = p.ticket_code
                where not t.is_test and p.status = 'lost'),
    'playing', (select count(*) from public.lc_plays p join public.lc_tickets t on t.code = p.ticket_code
                where not t.is_test and p.status = 'playing'),
    'abandoned', (select count(*) from public.lc_plays p join public.lc_tickets t on t.code = p.ticket_code
                where not t.is_test and p.status = 'abandoned'),
    'mssv_won', (select count(distinct mssv) from public.lc_completions where not is_test and mssv is not null),
    'by_form', coalesce((
      select jsonb_agg(x order by (x ->> 'form_type')::int) from (
        select jsonb_build_object('form_type', s.form_type, 'answers', count(*),
                                  'wrong', count(*) filter (where not a.correct)) as x
        from public.lc_answers a
        join public.lc_situations s on s.id = a.situation_id
        join public.lc_plays p on p.id = a.play_id
        join public.lc_tickets t on t.code = p.ticket_code
        where not t.is_test
        group by s.form_type) q), '[]'::jsonb),
    'by_situation', coalesce((
      select jsonb_agg(x order by (x ->> 'wrong')::int desc) from (
        select jsonb_build_object('situation_id', s.id, 'title', s.title, 'answers', count(*),
                                  'wrong', count(*) filter (where not a.correct)) as x
        from public.lc_answers a
        join public.lc_situations s on s.id = a.situation_id
        join public.lc_plays p on p.id = a.play_id
        join public.lc_tickets t on t.code = p.ticket_code
        where not t.is_test
        group by s.id, s.title) q), '[]'::jsonb)
  );
end $$;

-- ---------------------------------------------------------------------
-- 6. QUYỀN GỌI HÀM
-- ---------------------------------------------------------------------

revoke execute on function
  public.lc_gen_code(int), public.lc_norm(text), public.lc_situation_json(text),
  public.lc_pick_situation(int, text[]), public.lc_state_json(public.lc_plays),
  public.lc_check_ticket(text), public.lc_start(text, text, text, text, text, boolean),
  public.lc_resume(text), public.lc_answer(uuid, uuid, uuid, int),
  public.lc_is_admin(), public.lc_admin_create_tickets(int, text, boolean),
  public.lc_admin_batches(), public.lc_admin_tickets(text),
  public.lc_admin_completions(boolean), public.lc_admin_redeem(text, boolean),
  public.lc_admin_stats()
from public, anon, authenticated;

grant execute on function
  public.lc_check_ticket(text), public.lc_start(text, text, text, text, text, boolean),
  public.lc_resume(text), public.lc_answer(uuid, uuid, uuid, int)
to anon, authenticated;

grant execute on function
  public.lc_is_admin(), public.lc_admin_create_tickets(int, text, boolean),
  public.lc_admin_batches(), public.lc_admin_tickets(text),
  public.lc_admin_completions(boolean), public.lc_admin_redeem(text, boolean),
  public.lc_admin_stats()
to authenticated;

-- Kiểm tra nhanh: phải ra 12 tình huống, 48 món, 12 món ma túy.
select (select count(*) from public.lc_situations) as so_tinh_huong,
       (select count(*) from public.lc_items) as so_mon,
       (select count(*) from public.lc_items where is_drug) as so_mon_ma_tuy;
