/// Represents one row from the Blogs sheet, as seen by the admin app
/// (includes Drafts/Archived, unlike the public website).
class Blog {
  final int row;
  final String blogId;
  final String title;
  final String category;
  final String overview;
  final String content;
  final String status; // 'Draft' | 'Published' | 'Archived'
  final String image;
  final String slug;
  final DateTime? date;
  final String author;
  final int views;
  final bool featured;
  final String seoKeywords;
  final String metaDescription;

  Blog({
    required this.row,
    required this.blogId,
    required this.title,
    required this.category,
    required this.overview,
    required this.content,
    required this.status,
    required this.image,
    required this.slug,
    required this.date,
    required this.author,
    required this.views,
    required this.featured,
    required this.seoKeywords,
    required this.metaDescription,
  });

  factory Blog.fromJson(Map<String, dynamic> json) {
    DateTime? d;
    try {
      final raw = json['Date'] ?? json['Timestamp'];
      if (raw != null) d = DateTime.parse(raw.toString());
    } catch (_) {
      d = null;
    }
    return Blog(
      row: (json['_row'] is int)
          ? json['_row'] as int
          : int.tryParse('${json['_row']}') ?? 0,
      blogId: json['BlogID']?.toString() ?? '',
      title: json['Title']?.toString() ?? 'Untitled',
      category: json['Category']?.toString() ?? '',
      overview: json['Overview']?.toString() ?? '',
      content: json['Content']?.toString() ?? '',
      status: json['Status']?.toString() ?? 'Draft',
      image: json['Image']?.toString() ?? '',
      slug: json['Slug']?.toString() ?? '',
      date: d,
      author: json['Author']?.toString() ?? '',
      views: (json['Views'] is int)
          ? json['Views'] as int
          : int.tryParse('${json['Views']}') ?? 0,
      featured:
          json['Featured'] == true || json['Featured']?.toString() == 'true',
      seoKeywords: json['SEOKeywords']?.toString() ?? '',
      metaDescription: json['MetaDescription']?.toString() ?? '',
    );
  }
}
