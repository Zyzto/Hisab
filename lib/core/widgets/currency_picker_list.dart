import 'package:currency_picker/currency_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// In-app currency list for the picker bottom sheet.
///
/// - Sorts all lists alphabetically by currency code.
/// - Favourites at top; rest list excludes favourites (no duplicates).
/// - When searching, shows only matching currencies (no favourites section).
/// - Excludes certain currencies from the list (e.g. ILS, AED).
class AppCurrencyPickerList extends StatefulWidget {
  /// Currency codes to hide from the picker (e.g. ['ILS', 'AED']).
  static const excludedCurrencyCodes = {'ILS', 'AED'};
  const AppCurrencyPickerList({
    super.key,
    required this.onSelect,
    this.favorite,
    this.currencyFilter,
    this.showSearchField = true,
    this.showFlag = true,
    this.showCurrencyCode = true,
    this.showCurrencyName = true,
  }) : assert(
         showCurrencyCode || showCurrencyName,
         'showCurrencyCode and showCurrencyName cannot be both false',
       );

  final ValueChanged<Currency> onSelect;
  final List<String>? favorite;
  final List<String>? currencyFilter;
  final bool showSearchField;
  final bool showFlag;
  final bool showCurrencyCode;
  final bool showCurrencyName;

  @override
  State<AppCurrencyPickerList> createState() => _AppCurrencyPickerListState();
}

class _AppCurrencyPickerListState extends State<AppCurrencyPickerList> {
  final CurrencyService _currencyService = CurrencyService();
  final TextEditingController _searchController = TextEditingController();

  late List<Currency> _fullList;
  late List<Currency> _favoritesList;
  late List<Currency> _restList;

  static int _compareByCode(Currency a, Currency b) => a.code.compareTo(b.code);

  @override
  void initState() {
    super.initState();
    _buildLists();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _buildLists() {
    List<Currency> list = _currencyService.getAll();
    list = list
        .where(
          (c) => !AppCurrencyPickerList.excludedCurrencyCodes.contains(c.code),
        )
        .toList();

    if (widget.currencyFilter != null) {
      final codes = widget.currencyFilter!
          .map((e) => e.trim().toUpperCase())
          .where((e) => e.isNotEmpty)
          .toSet();
      list = list.where((c) => codes.contains(c.code)).toList();
    }

    list = List<Currency>.from(list)..sort(_compareByCode);
    _fullList = list;

    final orderedFavoriteCodes =
        widget.favorite != null && widget.favorite!.isNotEmpty
        ? widget.favorite!
              .map((e) => e.trim().toUpperCase())
              .where((e) => e.isNotEmpty)
              .toList()
        : <String>[];
    final favoriteCodes = orderedFavoriteCodes.toSet();

    // Preserve user settings order for favourites (no alphabetical sort).
    final codeToCurrency = {for (final c in list) c.code: c};
    _favoritesList = orderedFavoriteCodes
        .where((code) => codeToCurrency.containsKey(code))
        .map((code) => codeToCurrency[code]!)
        .toList();

    _restList =
        favoriteCodes.isEmpty
              ? list
              : list.where((c) => !favoriteCodes.contains(c.code)).toList()
          ..sort(_compareByCode);
  }

  List<Currency> _searchResults(String query) {
    if (query.isEmpty) return _fullList;
    final q = query.toLowerCase();
    return _fullList
        .where(
          (c) =>
              c.code.toLowerCase().contains(q) ||
              c.name.toLowerCase().contains(q),
        )
        .toList()
      ..sort(_compareByCode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _searchController.text.trim();
    final isSearching = query.isNotEmpty;
    final searchList = isSearching ? _searchResults(query) : <Currency>[];

    return Column(
      children: <Widget>[
        const SizedBox(height: 12),
        if (widget.showSearchField)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'search'.tr(),
                hintText: 'search'.tr(),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.2,
                    ),
                  ),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        Expanded(
          child: ListView(
            children: [
              if (isSearching) ...[
                ...searchList.map((currency) => _listRow(context, currency)),
              ] else ...[
                if (_favoritesList.isNotEmpty) ...[
                  ..._favoritesList.map((c) => _listRow(context, c)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: Divider(thickness: 1),
                  ),
                ],
                ..._restList.map((c) => _listRow(context, c)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _listRow(BuildContext context, Currency currency) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleMedium;
    final subtitleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final signStyle = theme.textTheme.titleMedium;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          widget.onSelect(currency);
          Navigator.pop(context);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9.0, horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Row(
                  children: [
                    const SizedBox(width: 15),
                    if (widget.showFlag) ...[
                      _flagWidget(context, currency),
                      const SizedBox(width: 15),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.showCurrencyCode)
                            Text(currency.code, style: titleStyle!),
                          if (widget.showCurrencyName)
                            Text(
                              currency.name,
                              style: widget.showCurrencyCode
                                  ? (subtitleStyle ?? titleStyle)
                                  : titleStyle,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(currency.symbol, style: signStyle!),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _flagWidget(BuildContext context, Currency currency) {
    if (currency.flag != null && !currency.isFlagImage) {
      return Text(
        CurrencyUtils.currencyToEmoji(currency),
        style: Theme.of(context).textTheme.headlineSmall,
      );
    }
    return const SizedBox(width: 27, height: 27);
  }
}
