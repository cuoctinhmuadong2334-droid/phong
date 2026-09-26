// ============================================================
//  THÔNG TIN CHUNG CỦA WEBSITE — sửa các dòng dưới đây là xong.
//  Dòng nào có chữ "MẪU" là nội dung tạm, cần thay bằng thông tin thật.
// ============================================================

export const site = {
  name: 'Nguyễn Vũ Phong',
  role: 'Camera Operator & Editor',
  tagline: 'Quay & dựng video kể chuyện bằng hình ảnh', // MẪU: slogan
  description: 'Nguyễn Vũ Phong — Camera Operator & Editor. Portfolio quay phim, dựng video.',

  // Video nền ở đầu trang: đặt file vào thư mục public/ rồi ghi đường dẫn, vd '/hero.mp4'.
  // Để trống ('') thì dùng ảnh thumbnail của showreel làm nền.
  heroVideo: '',
  heroPoster: '', // ảnh hiển thị khi video nền chưa tải, vd '/hero.jpg'

  // ID YouTube của showreel: link https://youtu.be/ABC123xyz  →  ID là 'ABC123xyz'
  showreelYoutubeId: 'aqz-KE-bpKQ', // MẪU

  contact: {
    phone: '0824890655', // cũng dùng cho Zalo
    email: '', // không bắt buộc
    location: '', // vd 'TP. Hồ Chí Minh'
  },

  // Để trống ('') mạng nào không dùng thì icon đó sẽ tự ẩn
  social: {
    facebook: 'https://www.facebook.com/share/1DtesZTzD9/?mibextid=wwXIfr',
    instagram: '',
    tiktok: '',
    youtube: '',
  },

  about: {
    photo: '', // vd '/chan-dung.jpg' (đặt file trong public/)
    bio: [
      'Mình là Nguyễn Vũ Phong, camera operator và editor — quay phim và dựng video.', // MẪU
      'Mình làm TVC cho thương hiệu, MV ca nhạc, video sự kiện và phim cưới — từ lên kịch bản, quay, dựng đến chỉnh màu.', // MẪU
    ],
    gear: ['Sony FX3', 'DJI Ronin RS3', 'DJI Mini 4 Pro', 'DaVinci Resolve', 'Premiere Pro'], // MẪU
    clients: ['Thương hiệu A', 'Công ty B', 'Nghệ sĩ C', 'Sự kiện D'], // MẪU
  },

  services: [
    {
      title: 'Quay phim',
      text: 'TVC, sự kiện, phỏng vấn, phim cưới. Có flycam và gimbal.',
    },
    {
      title: 'Dựng & hậu kỳ',
      text: 'Dựng theo kịch bản, nhịp nhạc, phụ đề, motion graphics cơ bản.',
    },
    {
      title: 'Chỉnh màu',
      text: 'Color grading trên DaVinci Resolve để có tông màu điện ảnh.',
    },
    {
      title: 'Video mạng xã hội',
      text: 'Clip dọc cho TikTok, Reels, Shorts — nhanh, bắt trend.',
    },
  ],
};

// Số điện thoại dạng quốc tế cho link gọi: 0900000000 → +84900000000
export const phoneIntl = '+84' + site.contact.phone.replace(/\D/g, '').replace(/^0/, '');
export const zaloLink = `https://zalo.me/${site.contact.phone.replace(/\D/g, '')}`;
export const telLink = `tel:${phoneIntl}`;

export const youtubeThumb = (id: string) => `https://i.ytimg.com/vi/${id}/hqdefault.jpg`;
export const youtubeEmbed = (id: string) =>
  `https://www.youtube-nocookie.com/embed/${id}?autoplay=1&rel=0&modestbranding=1&playsinline=1`;
