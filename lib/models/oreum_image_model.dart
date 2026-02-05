class OreumImageModel {
  static const String _storageBaseUrl = 'https://zsodcfgchbmmvpbwhuyu.supabase.co/storage/v1/object/public/oreum-data/';

  final String id;
  final String oreumId;
  final String _imageUrl;
  final String? imageSource;
  final int sortOrder;

  OreumImageModel({
    required this.id,
    required this.oreumId,
    required String imageUrl,
    this.imageSource,
    this.sortOrder = 0,
  }) : _imageUrl = imageUrl;

  // 전체 URL 반환
  String get imageUrl {
    if (_imageUrl.startsWith('http')) return _imageUrl;
    return '$_storageBaseUrl$_imageUrl';
  }

  factory OreumImageModel.fromJson(Map<String, dynamic> json) {
    return OreumImageModel(
      id: json['id'] ?? '',
      oreumId: json['oreum_id'] ?? '',
      imageUrl: json['image_url'] ?? '',
      imageSource: json['image_source'],
      sortOrder: json['sort_order'] ?? 0,
    );
  }
}
