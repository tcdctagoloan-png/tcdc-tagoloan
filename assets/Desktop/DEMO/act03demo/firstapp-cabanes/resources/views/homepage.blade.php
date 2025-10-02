<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Registration and Login Form</title>
</head>
<body>
    <h2>Registration and Login Form</h2>
    <table>
        <tr>
            <td>
                <h3>Register</h3>
                <form method="POST" action="/submit">
                  @csrf
                    <table>
                        <tr>
                            <td><label for="reg-username">Username:</label></td>
                            <td><input type="text" id="reg-username" name="username" required></td>
                        </tr>
                        <tr>
                            <td><label for="reg-email">Email:</label></td>
                            <td><input type="email" id="reg-email" name="email" required></td>
                        </tr>
                        <tr>
                            <td><label for="reg-password">Password:</label></td>
                            <td><input type="password" id="reg-password" name="password" required></td>
                        </tr>
                        <tr>
                            <td colspan="2">
                                <button type="submit">Register</button>
                            </td>
                        </tr>
                    </table>
                </form>
            </td>
            <td style="padding-left: 50px;">
                <h3>Login</h3>
                <form method="POST" action="/login">
                  @csrf
                    <table>
                        <tr>
                            <td><label for="login-username">Username:</label></td>
                            <td><input type="text" id="login-username" name="username" required></td>
                        </tr>
                        <tr>
                            <td><label for="login-password">Password:</label></td>
                            <td><input type="password" id="login-password" name="password" required></td>
                        </tr>
                        <tr>
                            <td colspan="2">
                                <button type="submit">Login</button>
                            </td>
                        </tr>
                    </table>
                </form>
            </td>
        </tr>
    </table>

  @if(session('logout_message'))
    <script>
        alert("{{ session('logout_message') }}");
    </script>
  @endif

  @if(session('incorrect_msg'))
  <script>
      alert("{{ session('incorrect_msg') }}");
  </script>
@endif

</body>
</html>
