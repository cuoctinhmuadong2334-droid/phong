import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

// Mỗi dự án là một file .md trong src/content/projects/
const projects = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/projects' }),
  schema: z.object({
    title: z.string(),
    client: z.string().optional(),
    year: z.number(),
    category: z.enum(['TVC', 'MV', 'Sự kiện', 'Phim cưới', 'Mạng xã hội', 'Phim ngắn']),
    role: z.string().optional(), // vd: 'Quay, dựng, chỉnh màu'
    youtubeId: z.string(),
    thumbnail: z.string().optional(), // để trống thì lấy ảnh từ YouTube
    preview: z.string().optional(), // clip .mp4 ngắn phát khi rê chuột (không bắt buộc)
    featured: z.boolean().default(false), // true = hiện lên đầu
    order: z.number().default(0), // số lớn hiện trước
  }),
});

export const collections = { projects };
