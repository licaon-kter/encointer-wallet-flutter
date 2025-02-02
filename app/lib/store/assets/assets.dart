import 'package:mobx/mobx.dart';

import 'package:encointer_wallet/store/app.dart';
import 'package:encointer_wallet/store/assets/types/transfer_data.dart';
import 'package:ew_polkadart/generated/encointer_kusama/types/pallet_balances/types/account_data.dart';

part 'assets.g.dart';

class AssetsStore extends _AssetsStore with _$AssetsStore {
  AssetsStore(super.store);
}

abstract class _AssetsStore with Store {
  _AssetsStore(this.rootStore);

  final AppStore rootStore;

  final String localStorageBlocksKey = 'blocks';

  final String cacheTokenBalanceKey = 'token_balance';
  final String cacheTxsKey = 'txs';
  final String cacheTimeKey = 'assets_cache_time';

  String _getCacheKey(String key) {
    return rootStore.getCacheKey(key);
  }

  @observable
  int? cacheTxsTimestamp = 0;

  @observable
  bool isTxsLoading = true;

  @observable
  bool submitting = false;

  @observable
  ObservableMap<String?, AccountData> balances = ObservableMap<String?, AccountData>();

  @observable
  Map<String, String> tokenBalances = <String, String>{};

  @observable
  int? txsCount = 0;

  @observable
  ObservableList<TransferData> txs = ObservableList<TransferData>();

  @observable
  int txsFilter = 0;

  @observable
  ObservableMap<int?, BlockData> blockMap = ObservableMap<int?, BlockData>();

  @observable
  List? announcements;

  @observable
  ObservableMap<String, double> marketPrices = ObservableMap<String, double>();

  @computed
  ObservableList<TransferData> get txsView {
    return ObservableList.of(txs.where((i) {
      return switch (txsFilter) {
        1 => i.to == rootStore.account.currentAddress,
        2 => i.from == rootStore.account.currentAddress,
        _ => true,
      };
    }));
  }

//  @computed
//  ObservableList<Map<String, dynamic>> get balanceHistory {
//    List<Map<String, dynamic>> res = List<Map<String, dynamic>>();
//    double total = Fmt.balanceDouble(
//        balances[rootStore.settings.networkState.tokenSymbol]);
//    txs.asMap().forEach((index, i) {
//      if (index != 0) {
//        TransferData prev = txs[index - 1];
//        if (i.from == rootStore.account.currentAddress) {
//          total -= double.parse(prev.amount);
//          // add transfer fee: 0.02KSM
//          total += 0.02;
//        } else {
//          total += double.parse(prev.amount);
//        }
//      }
//      res.add({
//        "time": DateTime.fromMillisecondsSinceEpoch(i.blockTimestamp * 1000),
//        "value": total
//      });
//    });
//    return ObservableList.of(res.reversed);
//  }

  @action
  Future<void> setAccountBalances(String? pubKey, Map<String, AccountData> accountDatas,
      {bool needCache = true}) async {
    if (rootStore.account.currentAccount.pubKey != pubKey) return;

    accountDatas.forEach((k, v) {
      balances[k] = v;
    });
  }

  @action
  Future<void> setAccountTokenBalances(
    String pubKey,
    Map? amt, {
    bool needCache = true,
  }) async {
    if (rootStore.account.currentAccount.pubKey != pubKey) return;

    tokenBalances = Map<String, String>.from(amt!);

    if (!needCache) return;
    await rootStore.localStorage.setAccountCache(
      pubKey,
      _getCacheKey(cacheTokenBalanceKey),
      amt,
    );
  }

  @action
  void setTxsLoading(bool isLoading) {
    isTxsLoading = isLoading;
  }

  @action
  Future<void> clearTxs() async {
    txs.clear();
  }

  /// I can not test this method. because it is not used anywhere else.
  /// But I did it to fix lint. If it is right I will uncomment this method below.
  /// But if not used maybe we can remove it.
  /// ```dart
  /// final futures = [
  ///   rootStore.localStorage.setAccountCache(rootStore.account.currentAccount.pubKey, _getCacheKey(cacheTxsKey), ls),
  ///   rootStore.localStorage.setAccountCache(rootStore.account.currentAccount.pubKey, _getCacheKey(cacheTimeKey), cacheTxsTimestamp),
  /// ];
  /// await Future.wait(futures);
  ///
  /// ```
  // @action
  // Future<void> addTxs(Map res, String address, {bool shouldCache = false}) async {
  //   if (rootStore.account.currentAddress != address) return;

  //   txsCount = res['count'] as int?;

  //   final ls = res['transfers'] as List?;
  //   if (ls == null) return;

  //   for (final i in ls) {
  //     final tx = TransferData.fromJson(i as Map<String, dynamic>);
  //     txs.add(tx);
  //   }

  //   if (shouldCache) {
  //     cacheTxsTimestamp = DateTime.now().millisecondsSinceEpoch;
  //     final futures = [
  //       rootStore.localStorage.setAccountCache(rootStore.account.currentAccount.pubKey, _getCacheKey(cacheTxsKey), ls),
  //       rootStore.localStorage
  //           .setAccountCache(rootStore.account.currentAccount.pubKey, _getCacheKey(cacheTimeKey), cacheTxsTimestamp)
  //     ];

  //     await Future.wait(futures);
  //   }
  // }

  @action
  void setTxsFilter(int filter) {
    txsFilter = filter;
  }

  @action
  void setSubmitting(bool isSubmitting) {
    submitting = isSubmitting;
  }

  @action
  void setAnnouncements(List data) {
    announcements = data;
  }

  @action
  void setMarketPrices(String token, String price) {
    marketPrices[token] = double.parse(price);
  }

  @action
  Future<void> loadAccountCache() async {
    // return if currentAccount not exist
    final pubKey = rootStore.account.currentAccountPubKey;
    if (pubKey == null || pubKey.isEmpty) {
      return;
    }

    final cache = await Future.wait([
      rootStore.localStorage.getAccountCache(pubKey, _getCacheKey(cacheTxsKey)),
      rootStore.localStorage.getAccountCache(pubKey, _getCacheKey(cacheTimeKey)),
      rootStore.localStorage.getAccountCache(pubKey, _getCacheKey(cacheTokenBalanceKey)),
    ]);
    if (cache[0] != null) {
      txs = ObservableList.of(
          List.of(cache[0]! as Iterable).map((i) => TransferData.fromJson(i as Map<String, dynamic>)).toList());
    } else {
      txs = ObservableList();
    }
    if (cache[1] != null) {
      cacheTxsTimestamp = cache[1] as int?;
    }
    if (cache[2] != null) {
      await setAccountTokenBalances(pubKey, cache[2]! as Map<String, dynamic>, needCache: false);
    } else {
      await setAccountTokenBalances(pubKey, {}, needCache: false);
    }
  }

  @action
  Future<void> loadCache() async {
    final ls = await rootStore.localStorage.getObject(localStorageBlocksKey) as List<dynamic>?;
    if (ls != null) {
      for (final i in ls) {
        // for now ls always returns null, when integrated transaction history please check type
        if (i is Map<String, dynamic> && blockMap[i['id']] == null) {
          blockMap[i['id'] as int] = BlockData.fromJson(i);
        }
      }
    }

    return loadAccountCache();
  }
}

class BlockData {
  const BlockData({
    this.id = 0,
    this.hash = '',
    this.time,
  });

  factory BlockData.fromJson(Map<String, dynamic> json) {
    return BlockData(
      id: json['id'] as int?,
      hash: json['hash'] as String?,
      time: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
    );
  }

  final int? id;
  final String? hash;
  final DateTime? time;

  Map<String, dynamic> toJson(BlockData block) {
    return {
      'id': block.id,
      'hash': block.hash,
      'timestamp': block.time?.millisecondsSinceEpoch ?? DateTime.now(),
    };
  }
}
