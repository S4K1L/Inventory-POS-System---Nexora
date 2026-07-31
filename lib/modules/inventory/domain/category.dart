/// A product category. Supports nesting via [parentId] (null = top level).
/// Stored at `companies/{companyId}/categories/{id}`.
class Category {
  const Category({
    required this.id,
    required this.name,
    this.parentId,
  });

  final String id;
  final String name;
  final String? parentId;

  factory Category.fromMap(String id, Map<String, dynamic> data) {
    return Category(
      id: id,
      name: (data['name'] ?? '') as String,
      parentId: data['parentId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'parentId': parentId,
      };
}
