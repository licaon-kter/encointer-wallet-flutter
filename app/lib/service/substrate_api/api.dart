import 'dart:async';
import 'dart:convert';

import 'package:ew_http/ew_http.dart';

import 'package:encointer_wallet/store/app.dart';
import 'package:encointer_wallet/mocks/ipfs_api.dart';
import 'package:encointer_wallet/service/ipfs/ipfs_api.dart';
import 'package:encointer_wallet/service/log/log_service.dart';
import 'package:encointer_wallet/service/substrate_api/account_api.dart';
import 'package:encointer_wallet/service/substrate_api/assets_api.dart';
import 'package:encointer_wallet/service/substrate_api/chain_api.dart';
import 'package:encointer_wallet/service/substrate_api/core/dart_api.dart';
import 'package:encointer_wallet/service/substrate_api/core/js_api.dart';
import 'package:encointer_wallet/service/substrate_api/encointer/encointer_api.dart';
import 'package:ew_polkadart/ew_polkadart.dart';

/// Global api instance
///
/// `late final` because it will be initialized exactly once in lib/app.dart.
late Api webApi;

class Api {
  const Api(
    this.store,
    this.js,
    this.provider,
    this.dartApi,
    this.account,
    this.assets,
    this.chain,
    this.encointer,
    this.ipfsApi,
    this._jsServiceEncointer,
  );

  factory Api.create(
    AppStore store,
    JSApi js,
    SubstrateDartApi dartApi,
    EwHttp ewHttp,
    String jsServiceEncointer, {
    bool isIntegrationTest = false,
  }) {
    final provider = ReconnectingWsProvider(Uri.parse(store.settings.endpoint.value!), autoConnect: false);
    return Api(
      store,
      js,
      provider,
      dartApi,
      AccountApi(store, js, provider),
      AssetsApi(store, js, EncointerKusama(provider)),
      ChainApi(store, provider),
      EncointerApi(store, js, dartApi, ewHttp, EncointerKusama(provider)),
      isIntegrationTest ? MockIpfsApi(ewHttp) : IpfsApi(ewHttp, gateway: store.settings.ipfsGateway),
      jsServiceEncointer,
    );
  }

  final AppStore store;
  final String _jsServiceEncointer;

  final JSApi js;
  final ReconnectingWsProvider provider;
  final SubstrateDartApi dartApi;
  final AccountApi account;
  final AssetsApi assets;
  final ChainApi chain;
  final EncointerApi encointer;
  final IpfsApi ipfsApi;

  Future<void> init() async {
    await Future.wait([
      dartApi.connect(store.settings.endpoint.value!),
      provider.connectToNewEndpoint(Uri.parse(store.settings.endpoint.value!)),

      // launch the webView and connect to the endpoint
      launchWebview(),
    ]);

    Log.d('launch the webView', 'Api');

    // need to do this from here as we can't access instance fields in constructor.
    account.setFetchAccountData(fetchAccountData);
  }

  Future<void> close() async {
    final futures = [
      stopSubscriptions(),
      closeWebView(),
      encointer.close(),
      provider.disconnect(),
    ];

    await Future.wait(futures);
  }

  Future<void> launchWebview({
    bool customNode = false,
  }) async {
    final connectFunc = customNode ? connectNode : connectNodeAll;

    Future<void> postInitCallback() async {
      // load keyPairs from local data
      await account.initAccounts();

      if (store.account.currentAddress.isNotEmpty) {
        await store.encointer.initializeUninitializedStores(store.account.currentAddress);
      }

      await connectFunc();
      await Future.wait([
        webApi.encointer.getPhaseDurations(),
        webApi.encointer.getCurrentPhase(),
        webApi.encointer.getNextPhaseTimestamp(),
      ]);
    }

    return js.launchWebView(_jsServiceEncointer, postInitCallback);
  }

  /// Evaluate javascript [code] in the webView.
  ///
  /// If [wrapPromise] is true, evaluation of [code] will directly be awaited and the result is returned.
  /// Otherwise, a future is created and put into the list of pending JS-calls.
  /// If [allowRepeat] is true, a call to the same JS-method can be made repeatedly. Otherwise, subsequent calls will
  /// not have any effect.
  Future<dynamic> evalJavascript(
    String code, {
    bool wrapPromise = true,
    // True is the safe approach; otherwise a crashing (and therefore not returning) JS-call, will prevent subsequent
    // calls to the same method.
    bool allowRepeat = true,
  }) {
    return js.evalJavascript(code, wrapPromise: wrapPromise, allowRepeat: allowRepeat);
  }

  Future<void> connectNode() async {
    final node = store.settings.endpoint.value;
    final config = store.settings.endpoint.overrideConfig;
    // do connect
    final res = await evalJavascript('settings.connect("$node", "${jsonEncode(config)}")');
    if (res == null) {
      Log.d('connecting to node failed', 'Api');
      store.settings.setNetworkName(null);
      return;
    }

    if (store.settings.endpointIsTeeProxy) {
      // The JS-implementation used to be here.
      Log.p('Should connect to tee proxy here.');
    }

    await fetchNetworkProps();
  }

  Future<void> connectNodeAll() async {
    final nodes = store.settings.endpointList.map((e) => e.value).toList();
    final configs = store.settings.endpointList.map((e) => e.overrideConfig).toList();
    Log.d('connectNodeAll: configs = $configs', 'Api');

    // do connect
    final res = await evalJavascript('settings.connectAll(${jsonEncode(nodes)}, ${jsonEncode(configs)})');
    if (res == null) {
      Log.d('connect failed', 'Api');
      store.settings.setNetworkName(null);
      return;
    }

    if (store.settings.endpointIsTeeProxy) {
      // The JS-implementation used to be here.
      Log.p('Should connect to tee proxy here.');
    }

    final index = store.settings.endpointList.indexWhere((i) => i.value == res);
    if (index < 0) return;
    store.settings.setEndpoint(store.settings.endpointList[index]);
    await fetchNetworkProps();
    Log.d('get community data', 'Api');

    encointer.getCommunityData();
  }

  void fetchAccountData() {
    assets.fetchBalance();
    encointer.getCommunityData();
  }

  Future<void> fetchNetworkProps() async {
    // fetch network info
    final info = await Future.wait([
      evalJavascript('settings.getNetworkConst()'),
      evalJavascript('api.rpc.system.properties()'),
      evalJavascript('api.rpc.system.chain()'), // "Development" or "Encointer Testnet Gesell" or whatever
    ]);

    await Future.wait([
      store.settings.setNetworkConst(info[0] as Map<String, dynamic>),
      store.settings.setNetworkState(info[1] as Map<String, dynamic>)
    ]);

    store.settings.setNetworkName(info[2] as String?);

    startSubscriptions();
  }

  void startSubscriptions() {
    encointer.startSubscriptions();
    chain.startSubscriptions();
    assets.startSubscriptions();
  }

  Future<void> stopSubscriptions() async {
    await encointer.stopSubscriptions();
    await chain.stopSubscriptions();
    await assets.stopSubscriptions();
  }

  Future<void> subscribeMessage(
    String code,
    String channel,
    Function callback,
  ) async {
    await js.subscribeMessage(code, channel, callback);
  }

  Future<void> unsubscribeMessage(String channel) async {
    await js.unsubscribeMessage(channel);
  }

  Future<bool> isConnected() async {
    final connected = await evalJavascript('settings.isConnected()');
    Log.d('Api is connected: $connected', 'Api');

    return connected as bool;
  }

  Future<void> closeWebView() async {
    await stopSubscriptions();
    return js.closeWebView();
  }
}

class ReconnectingWsProvider extends Provider {
  ReconnectingWsProvider(this.url, {bool autoConnect = true})
      : provider = WsProvider(
          url,
          autoConnect: autoConnect,
        );

  final Uri url;
  WsProvider provider;

  Future<void> connectToNewEndpoint(Uri url) async {
    await disconnect();
    provider = WsProvider(url);
  }

  @override
  Future connect() {
    if (isConnected()) {
      return Future.value();
    } else {
      // We want to use a new channel even if the channel exists but it was closed.
      provider.channel = null;
      provider = WsProvider(url, autoConnect: false);
      return provider.connect();
    }
  }

  @override
  Future disconnect() async {
    // We only care if the channel is not equal to null.
    // Because we still want the internal cleanup if
    // the connection was closed from the other end.
    if (provider.channel == null) {
      return Future.value();
    } else {
      try {
        await provider.disconnect();
      } catch (e) {
        Log.e('Error disconnecting websocket: $e', 'ReconnectingWsProvider');
        return Future.value();
      }
    }
  }

  @override
  bool isConnected() {
    // the `provider.isConnected()` check is wrong upstream.
    // Hence, we implement it ourselves.
    final channel = provider.channel;
    return channel != null && channel.closeCode == null;
  }

  @override
  Future<RpcResponse> send(String method, List<dynamic> params) async {
    // Connect if disconnected
    await connect();
    return provider.send(method, params);
  }

  @override
  Future<SubscriptionResponse> subscribe(
    String method,
    List<dynamic> params, {
    FutureOr<void> Function(String subscription)? onCancel,
  }) async {
    // Connect if disconnected
    await connect();
    return provider.subscribe(method, params, onCancel: onCancel);
  }
}
