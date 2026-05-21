part of "add_item_screen.dart";

mixin _AddItemScreenFields on State<AddItemScreen> {
  final _titleController = TextEditingController();
  MediaAuthor? _selectedAuthor;
  String _authorQuery = "";
  final _formKey = GlobalKey<FormState>();
  String _selectedType = "book";
  String? _selectedFileName;
  String? _selectedFileMime;
  MediaUploadPayload? _selectedFileUpload;
  MediaUploadPayload? _selectedCoverUpload;
  List<String> _selectedGenres = [];
  String? _genrePickerValue;
  bool _isSubmitting = false;
  bool _isPickingFile = false;
  bool _isPickingCover = false;
  String? _error;
}
