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


window.calculateArea = function () {

  console.log("clicked")

  const triangles = document.querySelectorAll(".triangle")

  let total = 0

  triangles.forEach(tri => {

    const a = parseFloat(tri.querySelector(".a").value)
    const b = parseFloat(tri.querySelector(".b").value)
    const c = parseFloat(tri.querySelector(".c").value)

    console.log(a,b,c)

    if(!a || !b || !c) return

    const s = (a + b + c) / 2
    const area = Math.sqrt(s * (s-a) * (s-b) * (s-c))

    total += area

  })

  console.log("area =", total)

  document.getElementById("result").innerText ="合計面積: " + total.toFixed(2) + " m² "
}