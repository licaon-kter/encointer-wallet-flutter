// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i5;
import 'dart:typed_data' as _i6;

import 'package:polkadart/polkadart.dart' as _i1;
import 'package:polkadart/scale_codec.dart' as _i4;

import '../types/encointer_primitives/faucet/faucet.dart' as _i3;
import '../types/encointer_runtime/runtime_call.dart' as _i7;
import '../types/frame_support/pallet_id.dart' as _i9;
import '../types/pallet_encointer_faucet/pallet/call.dart' as _i8;
import '../types/sp_core/crypto/account_id32.dart' as _i2;

class Queries {
  const Queries(this.__api);

  final _i1.StateApi __api;

  final _i1.StorageMap<_i2.AccountId32, _i3.Faucet> _faucets = const _i1.StorageMap<_i2.AccountId32, _i3.Faucet>(
    prefix: 'EncointerFaucet',
    storage: 'Faucets',
    valueCodec: _i3.Faucet.codec,
    hasher: _i1.StorageHasher.identity(_i2.AccountId32Codec()),
  );

  final _i1.StorageValue<BigInt> _reserveAmount = const _i1.StorageValue<BigInt>(
    prefix: 'EncointerFaucet',
    storage: 'ReserveAmount',
    valueCodec: _i4.U128Codec.codec,
  );

  _i5.Future<_i3.Faucet?> faucets(
    _i2.AccountId32 key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _faucets.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _faucets.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  _i5.Future<BigInt> reserveAmount({_i1.BlockHash? at}) async {
    final hashedKey = _reserveAmount.hashedKey();
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _reserveAmount.decodeValue(bytes);
    }
    return BigInt.zero; /* Default */
  }

  /// Returns the storage key for `faucets`.
  _i6.Uint8List faucetsKey(_i2.AccountId32 key1) {
    final hashedKey = _faucets.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `reserveAmount`.
  _i6.Uint8List reserveAmountKey() {
    final hashedKey = _reserveAmount.hashedKey();
    return hashedKey;
  }
}

class Txs {
  const Txs();

  /// See [`Pallet::create_faucet`].
  _i7.RuntimeCall createFaucet({
    required name,
    required amount,
    whitelist,
    required dripAmount,
  }) {
    final _call = _i8.Call.values.createFaucet(
      name: name,
      amount: amount,
      whitelist: whitelist,
      dripAmount: dripAmount,
    );
    return _i7.RuntimeCall.values.encointerFaucet(_call);
  }

  /// See [`Pallet::drip`].
  _i7.RuntimeCall drip({
    required faucetAccount,
    required cid,
    required cindex,
  }) {
    final _call = _i8.Call.values.drip(
      faucetAccount: faucetAccount,
      cid: cid,
      cindex: cindex,
    );
    return _i7.RuntimeCall.values.encointerFaucet(_call);
  }

  /// See [`Pallet::dissolve_faucet`].
  _i7.RuntimeCall dissolveFaucet({
    required faucetAccount,
    required beneficiary,
  }) {
    final _call = _i8.Call.values.dissolveFaucet(
      faucetAccount: faucetAccount,
      beneficiary: beneficiary,
    );
    return _i7.RuntimeCall.values.encointerFaucet(_call);
  }

  /// See [`Pallet::close_faucet`].
  _i7.RuntimeCall closeFaucet({required faucetAccount}) {
    final _call = _i8.Call.values.closeFaucet(faucetAccount: faucetAccount);
    return _i7.RuntimeCall.values.encointerFaucet(_call);
  }

  /// See [`Pallet::set_reserve_amount`].
  _i7.RuntimeCall setReserveAmount({required reserveAmount}) {
    final _call = _i8.Call.values.setReserveAmount(reserveAmount: reserveAmount);
    return _i7.RuntimeCall.values.encointerFaucet(_call);
  }
}

class Constants {
  Constants();

  final _i9.PalletId palletId = const <int>[
    101,
    99,
    116,
    114,
    102,
    99,
    116,
    48,
  ];
}
