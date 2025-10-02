<html>
    <body>
        <h1>Contact Information</h1>
        <form action="contactsubmit" method="POST">
           @csrf
           <label for="con_id">CONTACT ID:</label>
           <input type='text' id='con_id' name='con_id'><br><br>
           
            <label for="con_moth_name">Mother's Name:</label>
            <input type='text' id='con_moth_name' name='con_moth_name'><br><br>
            
            <label for="con_moth_num">Mother's Number:</label>
            <input type='text' id='con_moth_num' name='con_moth_num'><br><br>
            
            <label for="con_fath_name">Father's Name:</label>
            <input type='text' id='con_fath_name' name='con_fath_name'><br><br>
            
            <label for="con_fath_num">Father's Number:</label>
            <input type='text' id='con_fath_num' name='con_fath_num'><br><br>
            
            <label for="con_guardname">Guardian's Name:</label> 
            <input type='text' id='con_guardname' name='con_guardname'><br><br>
            
            <label for="con_guardnum">Guardian's Number:</label>
            <input type='text' id='con_guardnum' name='con_guardnum'><br><br>

            <button onclick="window.history.back()">Back</button>
            <button type='submit'>Save</button>
        </form>
    </body>
</html>
