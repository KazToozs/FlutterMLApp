// Copyright 2018-present the Flutter authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:scoped_model/scoped_model.dart';

import 'package:shrine_with_square/colors.dart';
import 'package:shrine_with_square/expanding_bottom_sheet.dart';
import 'package:shrine_with_square/model/app_state_model.dart';
import 'package:shrine_with_square/model/payments_repository.dart';
import 'package:shrine_with_square/model/product.dart';
import 'package:square_in_app_payments/in_app_payments.dart';
import 'package:square_in_app_payments/models.dart';
import 'package:path/path.dart' show basename;
import 'service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';


const double _leftColumnWidth = 60.0;
GlobalKey<ScaffoldState> _key = GlobalKey();

class ShoppingCartPage extends StatefulWidget {
  @override
  _ShoppingCartPageState createState() => _ShoppingCartPageState();
}

class _ShoppingCartPageState extends State<ShoppingCartPage> {
  List<Widget> _createShoppingCartRows(AppStateModel model) {
    return model.productsInCart.keys
        .map(
          (int id) => ShoppingCartRow(
                product: model.getProductById(id),
                quantity: model.productsInCart[id],
                onPressed: () {
                  model.removeItemFromCart(id);
                },
              ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData localTheme = Theme.of(context);

    return Scaffold(
      backgroundColor: kShrinePink50,
      body: SafeArea(
        child: Container(
          child: ScopedModelDescendant<AppStateModel>(
            builder: (BuildContext context, Widget child, AppStateModel model) {
              return Stack(
                children: <Widget>[
                  ListView(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          SizedBox(
                            width: _leftColumnWidth,
                            child: IconButton(
                              icon: const Icon(Icons.keyboard_arrow_down),
                              onPressed: () =>
                                  ExpandingBottomSheet.of(context).close(),
                            ),
                          ),
                          Text(
                            'CHECKOUT',
                            style: localTheme.textTheme.subhead
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 16.0),
                        ],
                      ),
                      const SizedBox(height: 16.0),
                      Column(
                        children: _createShoppingCartRows(model),
                      ),
                      ShoppingCartSummary(model: model),
                      const SizedBox(height: 100.0),
                    ],
                  ),
                  Positioned(
                    bottom: 16.0,
                    left: 16.0,
                    right: 16.0,
                    child: model.predictionImage != null
                        ? _prettyButton(model, 'MAKE PAYMENT', _payment)
                        : Text('Please select an image to analyse')
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }


  Future<List<String>> _uploadPhoto(File image) async {
    final fileName = basename(image.path);
    final storageRef = FirebaseStorage.instance.ref().child(fileName);

    //show loading animation
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return SimpleDialog(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    CircularProgressIndicator(),
                    Container(
                        padding: EdgeInsets.only(left: 10.0),
                        child: Text('Working...',
                          textAlign: TextAlign.center,))
                  ],
                ),
              ),
            ],
          );
        }
    );

    final uploadTask = storageRef.putFile(image);
    final taskSnapshot = await uploadTask.onComplete;
    final url = await storageRef.getDownloadURL();




    return [fileName, url];
  }


  Future<void> showErrorDialog(String title, String message) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(message),
              ],
            ),
          ),
          actions: <Widget>[
            FlatButton(
              child: Text('Ok'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }


  void _classifyPhoto(File file) async {
      final _restService = RestService();

      try {
        final data = await _uploadPhoto(file);
        bool prediction = await _restService.classifyPhoto(data[0], data[1]);
        String output;
        if (prediction) {
          output = 'Palm oil plantation detected!';
        }
        else
          output = 'No palm oil plantation detected';


        Navigator.pop(context);
        showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return SimpleDialog(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                        padding: EdgeInsets.only(left: 10.0),
                        child: Text(output,
                          textAlign: TextAlign.center,)),
                  ),
                  new SimpleDialogOption(child: new Text('Ok'),onPressed: (){Navigator.pop(context);},),
                ],
              );
            }
        );

      }
      catch(e){



        showErrorDialog("Error", "Cannot process this photo :c");
      }
  }

  _prediction(AppStateModel model) {
    // take image and pass through model
    _classifyPhoto(model.predictionImage);

    // Return to app and close shopping cart
    //ExpandingBottomSheet.of(context).close();

    // make popup displaying result
  }

  _payment(AppStateModel model) async {
    await InAppPayments.setSquareApplicationId('sq0idp-lz-UZLXxZvxvtVeGkfUT1A');
    await InAppPayments.startCardEntryFlow(
        onCardNonceRequestSuccess: (CardDetails result) {
          try {
            var chargeResult =
                PaymentsRepository.actuallyMakeTheCharge(result.nonce);
            if (chargeResult != 'Success!') throw new StateError(chargeResult);
            InAppPayments.completeCardEntry(
               // onCardEntryComplete: ExpandingBottomSheet.of(context).close);
              onCardEntryComplete: _prediction(model));
          } catch (ex) {
            InAppPayments.showCardNonceProcessingError(ex.toString());
          }
        },
        onCardEntryCancel: () {});
    //ExpandingBottomSheet.of(context).close();
  }

  Widget _prettyButton(AppStateModel model, String text, Function action) {
    return RaisedButton(
      shape: const BeveledRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(7.0)),
      ),
      color: kShrinePink100,
      splashColor: kShrineBrown600,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12.0),
        child: Text(text),
      ),
      onPressed: () => action(model),
    );
  }
}

class ShoppingCartSummary extends StatelessWidget {
  const ShoppingCartSummary({this.model});

  final AppStateModel model;

  @override
  Widget build(BuildContext context) {
    final TextStyle smallAmountStyle =
        Theme.of(context).textTheme.body1.copyWith(color: kShrineBrown600);
    final TextStyle largeAmountStyle = Theme.of(context).textTheme.display1;
    final NumberFormat formatter = NumberFormat.simpleCurrency(
      decimalDigits: 2,
      locale: Localizations.localeOf(context).toString(),
    );

    return Row(
      children: <Widget>[
        const SizedBox(width: _leftColumnWidth),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Column(
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    const Expanded(
                      child: Text('PREDICTION COST'),
                    ),
                    Text(
                      formatter.format(model.totalCost),
                      style: largeAmountStyle,
                    ),
                  ],
                ),
                
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ShoppingCartRow extends StatelessWidget {
  const ShoppingCartRow({
    @required this.product,
    @required this.quantity,
    this.onPressed,
  });

  final Product product;
  final int quantity;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final NumberFormat formatter = NumberFormat.simpleCurrency(
      decimalDigits: 0,
      locale: Localizations.localeOf(context).toString(),
    );
    final ThemeData localTheme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        key: ValueKey<int>(product.id),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: _leftColumnWidth,
            child: IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: onPressed,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Column(
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Image.asset(
                        product.assetName,
                        package: product.assetPackage,
                        fit: BoxFit.cover,
                        width: 75.0,
                        height: 75.0,
                      ),
                      const SizedBox(width: 16.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text('Quantity: $quantity'),
                                ),
                                Text('x ${formatter.format(product.price)}'),
                              ],
                            ),
                            Text(
                              product.name,
                              style: localTheme.textTheme.subhead
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  const Divider(
                    color: kShrineBrown900,
                    height: 10.0,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
