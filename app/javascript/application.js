window.addTriangle = function () {

  const container = document.getElementById("triangles")

  const div = document.createElement("div")
  div.className = "triangle"
  div.style.marginTop = "20px"

  div.innerHTML = `
    <hr>

    <label>辺A</label><br>
    <input type="number" class="a" style="width:100%;padding:10px">

    <br><br>

    <label>辺B</label><br>
    <input type="number" class="b" style="width:100%;padding:10px">

    <br><br>

    <label>辺C</label><br>
    <input type="number" class="c" style="width:100%;padding:10px">
  `

  container.appendChild(div)
}


function triangleArea(a,b,c){
  const s = (a + b + c) / 2;
  return Math.sqrt(s * (s-a) * (s-b) * (s-c));
}

function calculateArea(){

  const a = parseFloat(document.querySelector(".a").value) || 0;
  const b = parseFloat(document.querySelector(".b").value) || 0;
  const c = parseFloat(document.querySelector(".c").value) || 0;

  let total = 0;

  if(a && b && c){
    total = triangleArea(a,b,c);
  }

  document.getElementById("areaResult").innerText = total.toFixed(2);
  document.getElementById("haResult").innerText = (total / 10000).toFixed(4);

}