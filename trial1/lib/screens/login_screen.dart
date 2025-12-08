import 'package:flutter/material.dart';
import 'package:trial1/widgets/login_card.dart';


class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final logoPath = brightness == Brightness.dark
        ? "assets/university/dark_mode.png"
        : "assets/university/light_mode.png";

    return Scaffold(
      appBar: AppBar(
        backgroundColor: brightness == Brightness.dark ? Colors.black : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(
            color: brightness == Brightness.dark ? Colors.white : Colors.black),
        title: Hero(
          tag: "appLogo",
          child: Material(
            color: Colors.transparent,
            child: Row(
              children: [
                
                Text(
                  "Uni-Dash",
                  style: TextStyle(
                    fontSize: 30,
                    color: brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      body: Center(
        child: LoginRegisterCard(),
      ),
    );
  }
}
