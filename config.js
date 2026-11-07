// =====================================================================
// LUCID CART – TỆP CẤU HÌNH
// BTC chỉ cần sửa tệp này. Xem README.md, bước 4.
// =====================================================================
window.LUCID_CONFIG = {
  // Supabase Dashboard → Project Settings → API
  SUPABASE_URL: 'https://ativmwqcwhazlzkcluyv.supabase.co'
  SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF0aXZtd3Fjd2hhemx6a2NsdXl2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQwMDQ1MjQsImV4cCI6MjEwOTU4MDUyNH0.RmK8SlOmC4ON1GFftBi2SXhU9xA2AncngAVu54U50Vo'

  // Tên hiển thị của Ban Tổ chức
  ORGANIZER: 'Ban Tổ chức',

  WORKSHOP: {
    name: 'Shield Up',
    full_name: 'Workshop Trang bị Kỹ năng Nhận diện & Phòng vệ trước Ma túy thế hệ mới',
    time: '17g30, thứ Bảy 28/11/2026 (dự kiến)',
    place: 'Hội trường B1.205, cơ sở B – Đại học Kinh tế TP.HCM',
    // Dán đường dẫn đăng ký (Google Form…) vào đây. Để trống thì game hiện
    // dòng “BTC sẽ thông báo đường dẫn đăng ký”.
    register_url: '',
    agenda: [
      ['17g30', 'Khai mạc'],
      ['17g45', 'Chuyên đề 1: Điểm mới trong Luật Phòng, chống ma túy và chế tài xử lý'],
      ['18g45', 'Giải lao'],
      ['19g00', 'Chuyên đề 2: Giải mã thủ đoạn “núp bóng” và kỹ năng “3 Không”'],
      ['20g00', 'Hỏi đáp'],
      ['20g30', 'Tổng kết, bế mạc']
    ]
  },

  // Các dòng quyền lợi hiện trên màn hình hoàn thành
  BENEFITS: [
    'MSSV của bạn đã được ghi nhận hoàn thành trò chơi và sẽ được cập nhật lên hệ thống mã vạch.',
    'Tham gia đủ thời lượng Workshop: được cập nhật MSSV thêm một lần.',
    'Hoàn thành cả trò chơi và Workshop: được ghi nhận tiêu chí Hội nhập tốt – Mảng Kỹ năng cấp Khoa.'
  ],

  PLAY_WINDOW_TEXT: 'Trò chơi mở từ 12/11 đến hết 30/11/2026.'
};
