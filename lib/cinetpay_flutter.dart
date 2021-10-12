library cinetpay_flutter;

import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' as convert;

typedef DynamicValue = dynamic Function(dynamic);

class CinetpayFlutter extends StatefulWidget {
  final String price;
  final String name;
  final String idprod;
  final String typeprod;
  final String iduser;
  final String description;
  final String apikey;
  final String siteId;
  final String notifyUrl;
  final String currency;
  final Uuid idtransaction;
  final DynamicValue succescallback;
  final DynamicValue errorcallback;
  CinetpayFlutter(
      {Key key,
      @required this.price,
      @required this.name,
      @required this.idprod,
      this.typeprod,
      @required this.iduser,
      this.description,
      @required this.apikey,
      @required this.notifyUrl,
      @required this.siteId,
      this.currency,
      this.idtransaction,
      @required this.succescallback,
      @required this.errorcallback});
  @override
  _CinetpayFlutterState createState() => new _CinetpayFlutterState();
}

class _CinetpayFlutterState extends State<CinetpayFlutter> {
  InAppWebViewController webView;
  ContextMenu contextMenu;
  String url = "";
  double progress = 0;
  double progressV = 0;
  dynamic objetSend;
  dynamic crypted;
  String urlSend;
  int tab = 0;
  String signature;
  dynamic data;
  dynamic alldata;
  String cpm_trans_id;

  @override
  void initState() {
    super.initState();
    initCinetpay();
  }

  void initCinetpay() {
    var objetSendAll = {
      'prix': widget?.price ?? 0,
      'description': widget?.description ?? 'null',
      'name': widget?.name ?? 'null',
      'id_prod': widget?.idprod ?? 'null',
      'type_prod': widget?.typeprod ?? 'null',
      'id_user': widget?.iduser ?? 'null',
    };
    () async {
      var crypted = await crypt(objetSendAll, true);
      DateTime now = DateTime.now();
      String formatdate = DateFormat('yyyy-MM-dd HH:mm').format(now);

      var datecurrent = formatdate.toString();
      var uuid = Uuid();
      var iduid = widget?.idtransaction ?? uuid.v4();
      setState(() {
        cpm_trans_id = iduid;
      });
      var data1 = {
        'cpm_amount': widget?.price,
        'cpm_currency': widget?.currency ?? "XOF",
        'cpm_site_id': widget?.siteId,
        'cpm_trans_id': iduid,
        'cpm_trans_date': datecurrent,
        'cpm_payment_config': 'SINGLE',
        'cpm_page_action': 'PAYMENT',
        'cpm_version': 'V1',
        'cpm_language': 'fr',
        'cpm_designation': widget?.name,
        'cpm_custom': crypted,
        'apikey': widget?.apikey
      };
      var sign = await getsignature(data1);
      print("SIgnature générer !");
      signature = sign;
      setState(() {
        signature = sign;
      });
      // await new Future.delayed(const Duration(seconds: 5));

      var formdata = {
        'cpm_amount': widget?.price,
        'cpm_currency': widget?.currency ?? "XOF",
        'cpm_site_id': widget?.siteId,
        'cpm_trans_id': iduid,
        'cpm_trans_date': datecurrent,
        'cpm_payment_config': 'SINGLE',
        'cpm_page_action': 'PAYMENT',
        'cpm_version': 'V1',
        'cpm_language': 'fr',
        'cpm_designation': widget?.name,
        'cpm_custom': crypted,
        'apikey': widget?.apikey,
        'signature': signature,
        'notify_url': widget?.notifyUrl,
        'return_url': 'https://api.eclesify.com/public/cinetpay_other_return',
        'cancel_url': 'https://api.eclesify.com/public/cinetpay_other_cancel'
      };
      print("initalisation des données !");
      var all = await convertLine(formdata);
      alldata = all;
      setState(() {
        alldata = all;
      });
      // print(alldata);
    }();

    contextMenu = ContextMenu(
        menuItems: [
          ContextMenuItem(
              androidId: 1,
              iosId: "1",
              title: "Special",
              action: () async {
                print("Menu item Special clicked!");
              })
        ],
        onCreateContextMenu: (hitTestResult) async {
          print("onCreateContextMenu");
          print(hitTestResult.extra);
          print(await webView.getSelectedText());
        },
        onHideContextMenu: () {
          print("onHideContextMenu");
        },
        onContextMenuActionItemClicked: (contextMenuItemClicked) {
          var id = (Platform.isAndroid)
              ? contextMenuItemClicked.androidId
              : contextMenuItemClicked.iosId;
          print("onContextMenuActionItemClicked: " +
              id.toString() +
              " " +
              contextMenuItemClicked.title);
        });
  }

  convertLine(dynamic variabled) async {
    var finl = "";
    var olle = variabled.keys;
    var i = 0;
    // print("1111111111111111111111111111111111");
    olle.forEach((key) {
      var ecom = i > 0 ? "&" : "";
      finl += ecom + key + "=" + variabled[key];
      i++;
    });
    // print(finl);
    return finl;
  }

  getResult(int an) async {
    var data1 = {
      'cpm_site_id': widget?.siteId,
      'cpm_trans_id': cpm_trans_id,
      'apikey': widget?.apikey
    };
    if (an == 1) {
      var res = await postdataResult(
          data1, "https://api.cinetpay.com/v1/?method=checkPayStatus");
      if (res != null) {
        var allval = res['transaction'] ?? null;
        if (allval != null) {
          if (allval['cpm_result'] == '00' &&
              allval['cpm_trans_status'] == "ACCEPTED") {
            widget.succescallback(allval);
            bouton() {
              Navigator.pop(context);
              Navigator.pop(context);
            }

            checkConnectivity(
                "Succès !",
                "Votre paiement à été effectué avec succès",
                "Continuer",
                bouton,
                "SUCCESS");
          } else {
            widget.errorcallback(allval);
            bouton() {
              Navigator.pop(context);
              Navigator.pop(context);
            }

            checkConnectivity("Echèc !", "Votre paiement à été réfusé ",
                "Continuer", bouton, "ERROR");
          }
        } else {
          widget.errorcallback({});
          bouton() {
            Navigator.pop(context);
            Navigator.pop(context);
          }

          checkConnectivity("Echèc !", "Votre paiement à été annulé", "Fermé",
              bouton, "WARNING");
        }
      } else {
        widget.errorcallback({});
        bouton() {
          Navigator.pop(context);
          Navigator.pop(context);
        }

        checkConnectivity("Erreur de paiement !", "Une erreur est survenue.",
            "Continuer", bouton, "ERROR");
      }
    } else {
      widget.errorcallback({});
      bouton() {
        Navigator.pop(context);
        Navigator.pop(context);
      }

      checkConnectivity(
          "Echèc !", "Votre paiement à été annulé", "Fermé", bouton, "WARNING");
    }
  }

  checkConnectivity(title, content, btn, Function tap, type) async {
    // await showDialog(
    //     barrierDismissible: false,
    //     useSafeArea: true,
    //     context: context,
    //     child: AlertDialog(
    //       title: Text(title),
    //       content: Text(content),
    //       actions: <Widget>[
    //         FlatButton(
    //             child: Text(
    //               btn,
    //               style: TextStyle(color: Colors.blueGrey),
    //             ),
    //             onPressed: tap
    //             //   Navigator.pop(context);
    //             // },
    //             )
    //       ],
    //     ));

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return CustomAlertDialog(
            type: type,
            title: title,
            content: content,
            buttonLabel: btn,
            btn: tap);
      },
    );
  }

  postdata(data, dynamic urls) async {
    var url = Uri.parse(urls);
    var response = await http.post(
        "https://api.cinetpay.com/v1/?method=getSignatureByPost",
        body: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      var jsonResponse = convert.jsonDecode(response.body);
      return jsonResponse;
    } else {
      return null;
    }
  }

  postdataResult(data, dynamic urls) async {
    try {
      var url = Uri.parse(urls);
      var response = await http.post(url, body: data);
      if (response.statusCode == 200 || response.statusCode == 201) {
        var jsonResponse =
            convert.jsonDecode(response.body) as Map<String, dynamic>;
        return jsonResponse;
      } else {
        return null;
      }
    } on Exception catch (_) {
      // only executed if error is of type Exception
      throw Exception("Error on server");
    } catch (error) {
      // executed for errors of all types other than Exception
      throw Exception("Error on server");
    }
  }

  getsignature(dynamic data) async {
    var postdatavalue = await postdata(
        data, "https://api.cinetpay.com/v1/?method=getSignatureByPost");
    return postdatavalue;
  }

  getFormattedDate(String date) async {}

  crypt(dynamic params, bool enc) async {
    Codec<String, String> stringToBase64Url = utf8.fuse(base64Url);
    if (enc == true) {
      String credentials = jsonEncode(params);
      String encoded = stringToBase64Url.encode(credentials);
      // encoded = stringToBase64Url.encode(encoded);
      return encoded; // dXNlcm5hbWU6cGFzc3dvcmQ=
    }
    String decoded = stringToBase64Url.decode(params);
    return decoded; // dXNlcm5hbWU6cGFzc3dvcmQ=
  }

  @override
  Widget build(BuildContext context) {
    var padding = MediaQuery.of(context).padding;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        resizeToAvoidBottomPadding: false,
        resizeToAvoidBottomInset: false,
        body: Container(
            child: Column(children: <Widget>[
          // Container(
          //   padding: EdgeInsets.only(top: 50.0),
          //   child: Text("CURRENT URL\n${url}"),
          // ),
          (progress < 1.0
              ? Container(
                  color: Colors.white,
                  alignment: Alignment.center,
                  padding: EdgeInsets.only(top: 50),
                  child: Center(
                      child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey[200],
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.blue))))
              : Container()),
          (alldata != null)
              ? Expanded(
                  child: Container(
                      // margin: const EdgeInsets.all(10.0),
                      padding: EdgeInsets.only(top: 50),
                      child: InAppWebView(
                        initialUrl: "https://secure.cinetpay.com",
                        contextMenu: contextMenu,
                        initialOptions: InAppWebViewGroupOptions(
                            crossPlatform: InAppWebViewOptions(
                          debuggingEnabled: false,
                          cacheEnabled: false,
                          clearCache: true,
                        )),
                        onWebViewCreated: (InAppWebViewController controller) {
                          webView = controller;
                          if (controller != null && alldata != null) {
                            controller.postUrl(
                                url: "https://secure.cinetpay.com",
                                postData:
                                    Uint8List.fromList(utf8.encode(alldata)));
                          }
                        },
                        onLoadStart:
                            (InAppWebViewController controller, String url) {
                          setState(() {
                            this.url = url;
                          });

                          if (url ==
                              "https://api.eclesify.com/public/cinetpay_other_cancel") {
                            print("error");
                            () async {
                              await getResult(2);
                            }();
                          }

                          if (url ==
                              "https://api.eclesify.com/public/cinetpay_other_return") {
                            () async {
                              await getResult(1);
                            }();
                          }
                        },
                        onCloseWindow: (controller) {
                          print(
                              "*********************************************************");
                        },
                        onLoadStop: (InAppWebViewController controller,
                            String url) async {
                          this.url = url;
                        },
                        onLoadError: (controller, url, code, message) {
                          print(code);
                          print(message);

                          widget.errorcallback({
                            "status": 500,
                            "code": code,
                            "message": message
                          });
                          bouton() {
                            Navigator.pop(context);
                            Navigator.pop(context);
                          }

                          checkConnectivity(code.toString(), message, "Fermé",
                              bouton, "ERROR");
                        },
                        onLoadHttpError:
                            (controller, url, statusCode, description) {
                          print(statusCode);
                          print(description);

                          widget.errorcallback({
                            "status": 500,
                            "code": statusCode,
                            "message": description
                          });
                          bouton() {
                            Navigator.pop(context);
                            Navigator.pop(context);
                          }

                          checkConnectivity(statusCode.toString(), description,
                              "Fermé", bouton, "ERROR");
                        },
                        onProgressChanged:
                            (InAppWebViewController controller, int progress) {
                          setState(() {
                            this.progress = progress / 100;
                          });
                        },
                      )),
                )
              : Container(
                  alignment: Alignment.center,
                  color: Colors.white,
                  height: MediaQuery.of(context).size.height -
                      padding.top -
                      padding.bottom -
                      55,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [Center(child: CircularProgressIndicator())])),
        ])),
      ),
    );
  }
}

class CustomAlertDialog extends StatelessWidget {
  final String type;
  final String title;
  final String content;
  final Widget icon;
  final String buttonLabel;
  final Function btn;
  final TextStyle titleStyle = TextStyle(
      fontSize: 20.0, color: Colors.black, fontWeight: FontWeight.bold);

  CustomAlertDialog(
      {Key key,
      this.title = "Successful",
      @required this.content,
      this.icon,
      this.type = "INFO",
      this.buttonLabel = "Ok",
      this.btn})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
        type: MaterialType.transparency,
        child: Container(
          alignment: Alignment.center,
          child: Container(
            margin: const EdgeInsets.all(8.0),
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20.0),
              color: Colors.white,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(height: 10.0),
                icon ??
                    Icon(
                      _getIconForType(type),
                      color: _getColorForType(type),
                      size: 50,
                    ),
                const SizedBox(height: 10.0),
                Text(
                  title,
                  style: titleStyle,
                  textAlign: TextAlign.center,
                ),
                Divider(),
                Text(
                  content,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 40.0),
                SizedBox(
                  width: double.infinity,
                  child: FlatButton(
                      padding: const EdgeInsets.all(5.0),
                      child: Text(buttonLabel),
                      onPressed: btn),
                ),
              ],
            ),
          ),
        ));
  }

  IconData _getIconForType(type) {
    switch (type) {
      case "WARNING":
        return Icons.warning;
      case "SUCCESS":
        return Icons.check_circle;
      case "ERROR":
        return Icons.error;
      case "INFO":
      default:
        return Icons.info_outline;
    }
  }

  Color _getColorForType(type) {
    switch (type) {
      case "WARNING":
        return Colors.orange;
      case "SUCCESS":
        return Colors.green;
      case "ERROR":
        return Colors.red;
      case "INFO":
      default:
        return Colors.blue;
    }
  }
}
